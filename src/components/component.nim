import tables
import sequtils

type
  Entity* = uint32
  Component* = ref object of RootObj
    entity* : Entity
  ComponentList* [T] = object
    components: TableRef[Entity, seq[T]]
  UniqueComponentList* [T] = object
    components: TableRef[Entity, T]

var currentEntityId* : Entity = 0

proc newEntity* : Entity =
  result = currentEntityId
  inc currentEntityId

#############
##ComponentList

proc newComponentList* [T] : ComponentList[T] =
  result = ComponentList[T](components: newTable[Entity, seq[T]]())

proc add* [T] (self: ComponentList[T], component: T) =
  if not self.components.hasKey(component.entity):
    self.components[component.entity] = @[]
  self.components[component.entity].add(component)

proc remove* [T] (self: ComponentList[T], entity: Entity) =
  if self.components.hasKey(entity):
    self.components.del(entity)

iterator items* [T] (self: ComponentList[T]): T =
  for entityComponents in self.components.values:
    for component in entityComponents:
      yield component

iterator `[]`* [T] (self: ComponentList[T], entity: Entity): T =
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

template defineComponent* (T, baseClass: typedesc, listAccessor, componentList: untyped) =
  let componentList = newComponentList[T]()

  iterator listAccessor* : T =
    for component in componentList:
      yield component

  iterator listAccessor* (self: Component): T =
    for component in componentList[self.entity]:
      yield component
  
  iterator listAccessor* (self: Entity): T =
    for component in componentList[self]:
      yield component
  
  when T is not Component:
    method add* (self: T) =
      procCall(baseClass(self).add())
      componentList.add(self)
    
    method removeEntityFromLists* (self: T) =
      procCall(baseClass(self).removeEntityFromLists())
      componentList.remove(self.entity)
    
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

############
## Callback system


#template listener* (procName: stmt, T: typedesc, componentList, body: stmt) {.immediate.} =
#  proc procName[T] (componentList: T) =
#    for component in T:
#      component.procName()
#  when not(compiles(proc procName[T] (componentList: T) = discard)):
#    proc procName[T] (componentList: T) =
#      for component in T:
#        component.procName()
#  proc procName(self: T) =
#    body





############
## Component implementation

defineComponent(Component, RootObj, components, componentList)

method add* (self: Component) {.base.} =
  componentList.add(self)

method removeEntityFromLists* (self: Component) {.base.} = discard

method onDestroy* (self: Component) {.base.} = discard

proc destroy* (self: Entity) =
  for component in self.components:
    component.removeEntityFromLists()
    component.onDestroy()
  componentList.remove(self)

