import component
import tables

type
  Transform = ref object of Component
    x : float
  Shape = ref object of Component

defineUniqueComponent(Transform, Component, getTransform, getTransforms, transformList)
defineUniqueComponent(Shape, Component, getShape, getShapes, shapeList)
#defineComponent(Transform, transforms)

#var ar = newTable[typedesc, int]()

#proc test[T]: int =
#  ar[T]

#echo test[Transform]

#let entity = newEntity()
let transform = Transform(entity: newEntity())
transform.add()

let b = transform.getTransform()

