//
// This file demonstrates how patterns matching syntax could be transformed into if statements.
//
// Author: Jens Lidestrom
//

class Comp
{
  Int age
  Str? name
  Comp? comp
  
  new make( |This| f ) {
    f( this )
  }
}

class Other {}

class PatternsTranslation
{
  Void patternTranslationExample( Obj? o )
  {

//   This is what code using the pattern matching proposal syntax would look like:
    
//    switch ( o ) {
//      case Comp{name = "woo"; age as a; comp = Comp{age = 3} as c} if (a > 2): 
//          echo( "Patt fields" )
//      case Other{ ... }: ... 
//      case ...
//      default:
//    }
    
//  The above could be translated into this:
    
    hasMatched := false
    
    if ( !hasMatched ) {
      
      // Case 1 start
      
      o1 := o as Comp // Comp{}
      
      if ( o1 != null ) // some value   
      {
        if ( o1.name == "woo" )
        {
          a := o1.age

          o2 := o1.comp as Comp
      
          if ( o2 != null )
          {
            c := o2
            
            if ( o2.age == 3 )
            {
              if ( a > 3 ) {
                // Matches!
                // Here we can use all containing var if we want to
                
                hasMatched = true
              }
            }
          }
        }
      }
      
      // Case 1 end

      // Case 2 start
      if ( !hasMatched ) {
        p1 := o as Other
        // ...
        
        // Case 2 end
        
        // Case 3 start
        if ( !hasMatched ) {
          // ...
          
          // Case 3 end
        }
      }
    }
    
  }

}
