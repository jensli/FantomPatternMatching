// Why is this commented out?

//
//class Animal
//{
//  Int i
//  
//  static Obj func( Str s ) {
//    return s
//  }
//}
//
//class Turtle : Animal {Int field1 := 1}
//
//class Frog : Animal {Int field2 := 2}
//
//
//const class Crow
//{
//  @PatternWildcard{ value = -1 }
//  const Int age
//  
//  @PatternWildcard{ value = null }
//  const Str? name
//  
//  @PatternExclude
//  const Int nr
//  
//  new make( Str? name, Int? age ) {
//    this.name = name
//    this.age = age
//    this.nr = -1
//  }
//  
//  new make2( Str? name, Int? age, Int nr ) {
//    this.name = name
//    this.age = age
//    this.nr = nr
//  }
//  
//  
//  
//  Int getA() { age }
//  
//  override Int hash() {
//    (age.hash + 31) * 31 + name.hash
//  }
//  
//  Void fn1() { echo( "fn1" ) }
//  
//  Void fn2() { echo( "fn2" ) }
//  
//  Void fnfn( |Obj? -> Void| f ) {
//    f( "f arg" )
//  }
//  
//  Void fn( Int i ) {
//    echo( "i: " + i )
//  }
//  
//  override Bool equals( Obj? other ) {
//    ExprSimpl.testEquals( this, other )
//  }
//  
////  override Bool equals( Obj? other ) {
////    
////    o := other as Some
////  
////    return o != null
////      && ( name == null || o.name == null || o.name == name )
////      && ( age == null || o.age == null || o.age == age )
////  }
//}
//
//
//const class PatternUtil
//{
//  static Facet? typeFacet( Type t, Type facetType ) {
//    return t.facets().find { it.typeof == facetType }
//  }
//
//  static Facet? baseTypeFacet( Type t, Type facetType )
//  {
//
//    
//    f := typeFacet( t, facetType )
//    
//    if ( f != null ) return f
//    
//    if ( t.base == null ) return null;
//    
//    return baseTypeFacet( t.base, facetType )
//  }
//  
//  static Facet? slotFacet( Slot t, Type facetType ) {
//    return t.facets().find { it.typeof == facetType }
//  }
//  
//}
//
//
//class PatternsExample
//{
//  
//  Void voidFn( |Obj?| fn ) {
//    fn( null )
//  }
//  
////  
////  Void testAlgType(Animal o)
////  {
////    switch (o) {
////      case t is Turtle: echo(t.field1)
////      case f is Frog: echo(f.field2)
////    }
////  }
////  
//  
//  Void testAlgTypeOld(Animal o)
//  {
////    if ( t := o as Turtle != null ) {
////      echo( t.field2 )
////    }
//    
//    switch ( o.typeof ) {
//      case Turtle#: echo(o->field1)
//      case Frog#: echo((o as Frog).field2)
//    }
//  }
//  
//  Void main()
//  {
//  }
//  
//  Void main_HIDE()
//  {
//    Obj o := Crow( "tjo2", 3 )
//    
//    switch ( o ) {
//      case Comp{name = "Woo"; age = 3}: echo( "as case" )
//      case Comp{}:
//      case Crow.make2( "tjo", -1, -111 ): echo( "Some tjo" )
//      case Crow( null, 3 ):               echo( "Waa" )
//      case Crow( "waa", 3 ):              echo( "Waa" )
//      case 1+2: echo( "1+2" )
//      default:                            echo( "Default" )
//      
//      
//    }
//  }
//  
//}
//
//
//
//
