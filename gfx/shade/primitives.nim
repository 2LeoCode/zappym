import std/math

type
  Bool* = distinct bool
  Int* = distinct int32
  UInt* = distinct uint32
  Float* = distinct float32
  Double* = distinct float64
  Primitive* = Bool or Int or UInt or Float or Double
  Array*[S, T] = distinct array[S, T]
  FixedSeq*[T] = distinct seq[T]
  PrimitiveKind* = enum
    pkBool = "Bool"
    pkInt = "Int"
    pkUInt = "UInt"
    pkFloat = "Float"
    pkDouble = "Double"

func `and`*(lhs: Bool, rhs: Bool): Bool {.borrow.}
func `or`*(lhs: Bool, rhs: Bool): Bool {.borrow.}
func `xor`*(lhs: Bool, rhs: Bool): Bool {.borrow.}
func `not`*(self: Bool): Bool {.borrow.}
func `and=`*(self: var Bool, other: Bool) =
  self = self and other
func `or=`*(self: var Bool, other: Bool) =
  self = self or other
func `xor=`*(self: var Bool, other: Bool) =
  self = self xor other
func `not=`*(self: var Bool) =
  self = not self

func `==`*(lhs: Bool, rhs: Bool): Bool {.borrow.}

func `and`*(lhs: Int, rhs: Int): Int {.borrow.}
func `or`*(lhs: Int, rhs: Int): Int {.borrow.}
func `xor`*(lhs: Int, rhs: Int): Int {.borrow.}
func `not`*(self: Int): Int {.borrow.}
func `shl`*(lhs: Int, rhs: UInt): Int {.borrow.}
func `shr`*(lhs: Int, rhs: UInt): Int {.borrow.}
func `and=`*(self: var Int, other: Int) =
  self = self and other
func `or=`*(self: var Int, other: Int) =
  self = self or other
func `xor=`*(self: var Int, other: Int) =
  self = self xor other
func `not=`*(self: var Int) =
  self = not self
func `shl=`*(self: var Int, n: UInt) =
  self = self shl n
func `shr=`*(self: var Int, n: UInt) =
  self = self shr n

func `+`*(lhs: Int, rhs: Int): Int {.borrow.}
func `+`*(self: Int): Int {.borrow.}
func `+=`*(self: var Int, other: Int) {.borrow.}
func `inc`*(self: var Int) {.borrow.}
func `succ`*(self: Int): Int {.borrow.}

func `-`*(lhs: Int, rhs: Int): Int {.borrow.}
func `-`*(self: Int): Int {.borrow.}
func `-=`*(self: var Int, other: Int) {.borrow.}
func `dec`*(self: var Int) {.borrow.}
func `pred`*(self: Int): Int {.borrow.}

func `*`*(lhs: Int, rhs: Int): Int {.borrow.}
func `*=`*(self: var Int, other: Int) {.borrow.}

func `div`*(lhs: Int, rhs: Int): Int {.borrow.}
func `div=`*(self: var Int, other: Int) =
  self = self div other

func `mod`*(lhs: Int, rhs: Int): Int {.borrow.}
func `mod=`*(self: var Int, other: Int) =
  self = self mod other

func `<`*(lhs: Int, rhs: Int): Bool {.borrow.}
func `<=`*(lhs: Int, rhs: Int): Bool {.borrow.}
func `==`*(lhs: Int, rhs: Int): Bool {.borrow.}

func `and`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `or`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `xor`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `not`*(self: UInt): UInt {.borrow.}
func `shl`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `shr`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `and=`*(self: var UInt, other: UInt) =
  self = self and other
func `or=`*(self: var UInt, other: UInt) =
  self = self or other
func `xor=`*(self: var UInt, other: UInt) =
  self = self xor other
func `not=`*(self: var UInt) =
  self = not self
func `shl=`*(self: var UInt, n: UInt) =
  self = self shl n
func `shr=`*(self: var UInt, n: UInt) =
  self = self shr n

func `+`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `+=`*(self: var UInt, other: UInt) {.borrow.}
func `inc`*(self: var UInt) {.borrow.}
func `succ`*(self: UInt): UInt {.borrow.}

func `-`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `-=`*(self: var UInt, other: UInt) {.borrow.}
func `dec`*(self: var UInt) {.borrow.}
func `pred`*(self: UInt): UInt {.borrow.}

func `*`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `*=`*(self: var UInt, other: UInt) {.borrow.}

func `div`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `div=`*(self: var UInt, other: UInt) =
  self = self div other

func `mod`*(lhs: UInt, rhs: UInt): UInt {.borrow.}
func `mod=`*(self: var UInt, other: UInt) =
  self = self mod other

func `<`*(lhs: UInt, rhs: UInt): Bool {.borrow.}
func `<=`*(lhs: UInt, rhs: UInt): Bool {.borrow.}
func `==`*(lhs: UInt, rhs: UInt): Bool {.borrow.}

func `+`*(lhs: Float, rhs: Float): Float {.borrow.}
func `+`*(self: Float): Float {.borrow.}
func `+=`*(self: var Float, other: Float) {.borrow.}

func `-`*(lhs: Float, rhs: Float): Float {.borrow.}
func `-`*(self: Float): Float {.borrow.}
func `-=`*(self: var Float, other: Float) {.borrow.}

func `*`*(lhs: Float, rhs: Float): Float {.borrow.}
func `*=`*(self: var Float, other: Float) {.borrow.}

func `/`*(lhs: Float, rhs: Float): Float {.borrow.}
func `/=`*(self: var Float, other: Float) {.borrow.}

func `%`*(lhs: Float, rhs: Float): Float =
  cast[Float](floorMod(cast[float32](lhs), cast[float32](rhs)))
func `%=`*(self: var Float, other: Float) =
  self = self % other

func `<`*(lhs: Float, rhs: Float): Bool {.borrow.}
func `<=`*(lhs: Float, rhs: Float): Bool {.borrow.}
func `==`*(lhs: Float, rhs: Float): Bool {.borrow.}

func `+`*(lhs: Double, rhs: Double): Double {.borrow.}
func `+=`*(self: var Double, other: Double) {.borrow.}

func `-`*(lhs: Double, rhs: Double): Double {.borrow.}
func `-=`*(self: var Double, other: Double) {.borrow.}

func `*`*(lhs: Double, rhs: Double): Double {.borrow.}
func `*=`*(self: var Double, other: Double) {.borrow.}

func `/`*(lhs: Double, rhs: Double): Double {.borrow.}
func `/=`*(self: var Double, other: Double) {.borrow.}

func `%`*(lhs: Double, rhs: Double): Double =
  cast[Double](floorMod(cast[float64](lhs), cast[float64](rhs)))

func `%=`*(self: var Double, other: Double) =
  self = self % other

converter toBool*(x: bool): Bool =
  Bool(x)

converter toBool*(x: Bool): bool =
  cast[bool](x)

converter toInt*(x: int32): Int =
  Int(x)

converter toInt*(x: static int): static Int =
  Int(x)

converter toInt*(x: static int64): static Int =
  Int(x)

converter toUInt*(x: int32): UInt =
  UInt(x)

converter toUInt*(x: uint32): UInt =
  UInt(x)

converter toUint*(x: Int): Uint =
  Uint(x)

converter toUInt*(x: static int): static UInt =
  UInt(x)

converter toUInt*(x: static int64): static UInt =
  UInt(x)

converter toUInt*(x: static uint): static UInt =
  UInt(x)

converter toUInt*(x: static uint64): static UInt =
  UInt(x)

converter toFloat*(x: int32): Float =
  Float(x)

converter toFloat*(x: uint32): Float =
  Float(x)

converter toFloat*(x: float32): Float =
  Float(x)

converter toFloat*(x: Int): Float =
  Float(x)

converter toFloat*(x: Uint): Float =
  Float(x)

converter toFloat*(x: static int): static Float =
  Float(x)

converter toFloat*(x: static int64): static Float =
  Float(x)

converter toFloat*(x: static uint): static Float =
  Float(x)

converter toFloat*(x: static uint64): static Float =
  Float(x)

converter toFloat*(x: static float64): static Float =
  Float(x)

converter toFloat*(x: static Double): static Float =
  Float(x)

converter toDouble*(x: int32): Double =
  Double(x)

converter toDouble*(x: uint32): Double =
  Double(x)

converter toDouble*(x: float32): Double =
  Double(x)

converter toDouble*(x: float64): Double =
  Double(x)

converter toDouble*(x: Int): Double =
  Double(x)

converter toDouble*(x: Uint): Double =
  Double(x)

converter toDouble*(x: Float): Double =
  Double(x)

func toTypePrefix*(self: sink PrimitiveKind): string =
  case self
  of pkBool: "B"
  of pkInt: "I"
  of pkUInt: "U"
  of pkFloat: ""
  of pkDouble: "D"
