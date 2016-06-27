import component
import tables
import events
import macros

type
  Transform = ref object of Component
  Shape = ref object of Component


defineUniqueComponent(Transform, Component)
defineGeneralComponent(Shape, Component)

Transform(entity: newEntity()).add()

Transform(entity: newEntity()).add()


Shape(entity: newEntity()).add()

let shapeEntity = newEntity();

Shape(entity: shapeEntity).add()
Shape(entity: shapeEntity).add()

let shapeB = Shape(entity: newEntity())
shapeB.add()

listener update, Transform:
  echo "Update transform "

listener update, Shape:
  echo "SHAPEYEAH!" 

update()