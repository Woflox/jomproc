import tables
import sequtils
import macros
import strutils

type
  Entity* = uint32
  Component* = ref object of RootObj
    entity* : Entity
  ComponentList* = ref object of RootObj
  GeneralComponentList* [T] = ref object of ComponentList
    components: TableRef[Entity, seq[T]]
  UniqueComponentList* [T] = ref object of ComponentList
    components: TableRef[Entity, T]

var currentEntityId* : Entity = 0

proc newEntity* : Entity =
  result = currentEntityId
  inc currentEntityId

#############
## GeneralComponentList

proc newGeneralComponentList* [T] : GeneralComponentList[T] =
  result = GeneralComponentList[T](components: newTable[Entity, seq[T]]())

proc add* [T] (self: GeneralComponentList[T], component: T) =
  if not self.components.hasKey(component.entity):
    self.components[component.entity] = @[]
  self.components[component.entity].add(component)

proc remove* [T] (self: GeneralComponentList[T], entity: Entity) =
  if self.components.hasKey(entity):
    self.components.del(entity)

iterator items* [T] (self: GeneralComponentList[T]): T =
  for entityComponents in self.components.values:
    for component in entityComponents:
      yield component

iterator `[]`* [T] (self: GeneralComponentList[T], entity: Entity): T =
  for component in self.components[entity]:
    yield component

###########
##UniqueComponentList

proc newUniqueComponentList* [T] : UniqueComponentList[T] =
  result = UniqueComponentList[T](components: newTable[Entity, T]())

proc add* [T] (self: UniqueComponentList[T], component: T) =
  self.components[component.entity] = component

proc remove* [T] (self: UniqueComponentList[T], entity: Entity) =
  if self.components.hasKey(entity):
    self.components.del(entity)

iterator items* [T] (self: UniqueComponentList[T]): T =
  for component in self.components.values:
    yield component

proc `[]`* [T] (self: UniqueComponentList[T], entity: Entity): T =
  self.components[entity]

#############
## Component template

template defineGeneralComponent* (T, baseClass: typedesc, listAccessor, componentList: untyped) =
  let componentList = newGeneralComponentList[T]()

  iterator listAccessor* : T =
    for component in componentList:
      yield component

  iterator listAccessor* (self: Component): T =
    for component in componentList[self.entity]:
      yield component
  
  iterator listAccessor* (self: Entity): T =
    for component in componentList[self]:
      yield component
  
  when baseClass is Component:
    method add* (self: T) =
      procCall(baseClass(self).add())
      componentList.add(self)
    
    method removeEntityFromLists* (self: T) =
      procCall(baseClass(self).removeEntityFromLists())
      componentList.remove(self.entity)

macro defineGeneralComponent* (typeName, baseTypeName: expr): stmt =
  parseStmt("defineGeneralComponent($1, $2, get$1s, list$1)".format(typeName.ident, baseTypeName.ident))

#############
## Unique component template

template defineUniqueComponent* (T, baseClass: typedesc, accessor, listAccessor, componentList: untyped) =
  let componentList = newUniqueComponentList[T]()

  iterator listAccessor* : T =
    for component in componentList:
      yield component

  proc accessor* (self: Component): T {.procvar.} =
    componentList[self.entity]

  proc accessor* (self: Entity): T =
    componentList[self]

  method add* (self: T) =
    procCall(baseClass(self).add())
    componentList.add(self)
  
  method removeEntityFromLists* (self: T) =
    procCall(baseClass(self).removeEntityFromLists())
    componentList.remove(self.entity)

macro defineUniqueComponent* (typeName, baseTypeName: expr): stmt =
  parseStmt("defineUniqueComponent($1, $2, get$1, get$1s, list$1)".format(typeName.ident, baseTypeName.ident))

############
## Callback system

template defineListener* (procName: untyped, T: typedesc, body: stmt) =
  proc procName(self: T) =
    body

template registerListener* (procName, callableList, callback: untyped, T: typedesc, componentList: untyped) =
  when not compiles(callableList[0]):
    var callableList* = newSeq[proc()]()
    proc procName() =
      for callbackProc in callableList:
        callbackProc()
  proc callback() =
    for component in componentList:
      component.procName()
  callableList.add(callback)
  echo "ADDING CALLBACK"

macro registerListener* (procName, typeName: expr): stmt =
  parseStmt("registerListener($1, $1List, $1$2s, $2, list$2)".format(procName.ident, typeName.ident))

template listener* (procName, T: untyped, body: stmt) =
  defineListener(procName, T, body)
  registerListener(procName, T)

############
## Component implementation

defineGeneralComponent(Component, RootObj, components, componentList)

method add* (self: Component) {.base.} =
  componentList.add(self)

method removeEntityFromLists* (self: Component) {.base.} = discard

method onDestroy* (self: Component) {.base.} = discard

proc destroy* (self: Entity) =
  for component in self.components:
    component.removeEntityFromLists()
    component.onDestroy()
  componentList.remove(self)

