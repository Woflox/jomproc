import tables
import sequtils
import macros
import strutils

type
  Entity* = uint32
  Component* = ref object of RootObj
    entity* : Entity
  GeneralComponentList* [T] = object
    components: TableRef[Entity, seq[T]]
  UniqueComponentList* [T] = object
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

iterator get* [T] (self: GeneralComponentList[T], entity: Entity): T =
  if self.components.hasKey(entity):
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

proc getUnique* [T] (self: UniqueComponentList[T], entity: Entity): T =
  self.components[entity]

iterator get* [T] (self: UniqueComponentList[T], entity: Entity): T =
  if self.components.hasKey(entity):
    yield self.components[entity]

#############
## Component template

template defineGeneralComponent* (T, baseClass: typedesc, listAccessor, componentList: untyped) =
  let componentList = newGeneralComponentList[T]()

  iterator listAccessor* : T =
    for component in componentList:
      yield component

  iterator listAccessor* (self: Component): T =
    for component in componentList.get(self.entity):
      yield component
  
  iterator listAccessor* (self: Entity): T =
    for component in componentList.get(self):
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
    componentList.getUnique(self.entity)

  proc accessor* (self: Entity): T =
    componentList.getUnique(self)

  method add* (self: T) =
    procCall(baseClass(self).add())
    componentList.add(self)
  
  method removeEntityFromLists* (self: T) =
    procCall(baseClass(self).removeEntityFromLists())
    componentList.remove(self.entity)

macro defineUniqueComponent* (typeName, baseTypeName: expr): stmt =
  parseStmt("defineUniqueComponent($1, $2, get$1, get$1s, list$1)".format(typeName.ident, baseTypeName.ident))

############
## Event listener system

proc parseProcDef (procDef: NimNode, skipFirst: bool): auto =
  let procName = $procDef.name
  var params = ""
  var paramsUntyped = ""
  var first = true
  var skip = skipFirst
  for i in 0..<procDef.params.len:
    let node = procDef.params[i]
    if node.len >= 3:
      for j in 0..<node.len-2:
        if first:
          if skip:
            skip = false
            continue
          first = false
        else:
          paramsUntyped &= ", "
          params &= ", "
        paramsUntyped &= $node[j].ident
        params &= $node[j].ident & ": " & repr(node[node.len-2])
  return (procName, params, paramsUntyped)

proc parseFirstParamType (procDef: NimNode): string =
  for i in 0..<procDef.params.len:
    let node = procDef.params[i]
    if node.len >= 3:
      return repr(node[node.len-2])


macro registerEvent* (procDefList: expr): stmt =
  result = newStmtList()
  for i in 0..<procDefList.len:
    var (procName, params, paramsUntyped) = parseProcDef(procDefList[i], false)
    var entityParams = "entity: Entity"
    var entityUntypedParams = "entity"
    if params.len > 0:
      entityParams &= ", " & params
      entityUntypedParams &= ", " & paramsUntyped
    let code = """
var $1List* = newSeq[proc ($2)]()
var $1EntityList* = newSeq[proc (entity: Entity, $2)]()
proc $1* ($2) =
  for callbackProc in $1List:
    callbackProc($3)
proc $1* ($4) =
  for callbackProc in $1EntityList:
    callbackProc($5)
""".format(procName, params, paramsUntyped, entityParams, entityUntypedParams)
    let stmts = parseStmt(code)
    for j in 0..<stmts.len:
      result.add(stmts[j])

macro listener* (procDef: stmt): stmt =
  result = newStmtList()
  result.add(procDef)
  var (procName, params, paramsUntyped) = parseProcDef(procDef, true)
  var entityParams = "entity: Entity"
  if params.len > 0:
    entityParams &= ", " & params
  let componentType = parseFirstParamType(procDef)
  let code = """
proc $1$5s($2) =
  for component in list$5:
    component.$1($3)
proc $1Entity$5s($4) =
  for component in list$5.get(entity):
    component.$1($3)
$1List.add($1$5s)
$1EntityList.add($1Entity$5s)
""".format(procName, params, paramsUntyped, entityParams, componentType)
  result.add(parseStmt(code))

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

