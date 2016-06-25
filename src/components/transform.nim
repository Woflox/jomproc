import component
import tables

type
  Transform = ref object of Component
    x : float

defineComponent(Transform, transform, transforms, transformList)
#defineComponent(Transform, transforms)

#var ar = newTable[typedesc, int]()

#proc test[T]: int =
#  ar[T]

#echo test[Transform]

#let entity = newEntity()
