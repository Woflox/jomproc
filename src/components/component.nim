import tables

type
  Entity* = uint32
  Component* = ref object of RootObj
    entity: Entity
  ComponentList* = ref object
    index: int
    components: TableRef[Entity, seq[Component]]


var currentEntityId* : Entity = 0
var componentLists* : seq[ComponentList] = @[]

proc newEntity* : Entity =
  result = currentEntityId
  inc currentEntityId

proc newComponentList* : ComponentList =
  result = ComponentList(index: componentLists.len, components: newTable[Entity, seq[Component]]())
  componentLists.add(result)

proc add* (self: ComponentList, entity: Entity, component: Component) =
  if not self.components.hasKey(entity):
    self.components[entity] = @[]
  self.components[entity].add(component)

iterator items* (self: ComponentList): Component =
  for entityComponents in self.components.values:
    for component in entityComponents:
      yield component

iterator `[]`* (self: ComponentList, entity: Entity): Component =
  for component in self.components[entity]:
    yield component

proc getUnique* (self: ComponentList, entity: Entity): Component =
  self.components[entity][0]

#proc getUniqueComponent[T] (self: ComponentList, self: Entity): [T] =
    

template defineComponent* (typeName, accessor, listAccessor, componentList: stmt) {.immediate.} =
  let componentList = newComponentList()

  proc accessor* (self: Component): typeName = 
    componentList.getUnique(self.entity)
  
  iterator listAccessor* : typeName =
    componentList.items

  iterator listAccessor* (self: Component): typeName =
    for component in componentList[self.entity]:
      yield component
  
  iterator listAccessor* (self: Entity): typeName =
    for component in componentList[self]:
      yield component
    
  # proc addComponent*(self: Entity, component: typeName) = 

