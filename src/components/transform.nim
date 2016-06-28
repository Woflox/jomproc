import component
import tables
import macros

type
  Transform = ref object of Component
  Shape = ref object of Component


defineUniqueComponent(Transform, Component)
defineGeneralComponent(Shape, Component)

let ent = newEntity()
Transform(entity: ent).add()

Transform(entity: newEntity()).add()


Shape(entity: newEntity()).add()

let shapeEntity = newEntity();

Shape(entity: shapeEntity).add()
Shape(entity: shapeEntity).add()

registerEvent:
  proc update(dt: float)
  proc render()

proc update(self: Transform, dt: float) {.listener.} =
  echo "UPDATE TRANSFORM"

proc render(self: Shape) {.listener.} =
  echo "RENDER TRANSFORM"

update(4f)
shapeEntity.render()