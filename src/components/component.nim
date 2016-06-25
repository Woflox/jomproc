import tables

type
  Entity* = uint32
  Component* = ref object of RootObj
    entity: Entity
  ComponentList* [T] = object
    components: TableRef[Entity, seq[T]]


var currentEntityId* : Entity = 0

proc newEntity* : Entity =
  result = currentEntityId
  inc currentEntityId

proc newComponentList* [T] : ComponentList[T] =
  result = ComponentList[T](components: newTable[Entity, seq[T]]())

let components* = newComponentList[Component]()

proc add* [T] (self: ComponentList[T], entity: Entity, component: T) =
  if not self.components.hasKey(entity):
    self.components[entity] = @[]
  self.components[entity].add(component)

iterator items* [T] (self: ComponentList[T]): T =
  for entityComponents in self.components.values:
    for component in entityComponents:
      yield component

iterator `[]`* [T] (self: ComponentList[T], entity: Entity): T =
  for component in self.components[entity]:
    yield component

proc getUnique* [T] (self: ComponentList[T], entity: Entity): T =
  self.components[entity][0]
    

template defineComponent* (T, accessor, listAccessor, componentList: stmt) {.immediate.} =
  let componentList = newComponentList[T]()

  proc accessor* (self: Component): T = 
    componentList.getUnique(self.entity)
  
  proc accessor* (self: Entity): T = 
    componentList.getUnique(self)

  iterator listAccessor* : T =
    for component in componentList:
      yield component

  iterator listAccessor* (self: Component): T =
    for component in componentList[self.entity]:
      yield component
  
  iterator listAccessor* (self: Entity): T =
    for component in componentList[self]:
      yield component
