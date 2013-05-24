
class Comp
{
  Int age
  Str? name
  Comp? comp
  
  new make( |This| f ) {
    f( this )
  }
}

class PatternExample {

  Void patternExample(Obj o)
  {
    switch (o) {
      case Comp{name = "woo"; age as a; comp = Comp{age = 3} as c} if (a > 2): 
          echo( "Match pattern 1: ${a} ${c}" )

      case [1, _ as snd]:
          echo("List pattern. Second list elem: " + snd)
      
      case ["key1": 1, "key2": _ as val2]:
          echo("Map pattern. key2: " + key2)
      
      case 17:
          echo("Simple literal")
      default:
          echo("Default")
    }
  }
  
}




//
//class Animal{Animal? parent := null}
//
//class Turtle : Animal{Int field1 := 1}
//
//class Frog : Animal{Int field2 := 2}
//
//
//class PatternExample {
//
//  Void patternExample(Animal o)
//  {
//    switch (o) {
//      case Turtle{field1 = 2; parent = Frog{} as par}  if (par.field2 > 7):
//          echo("Object pattern. Parent: " + par)
//
//      case [1, _ as snd]:
//          echo("List pattern. Second list elem: " + snd)
//      
//      case ["key1": 1, "key2": _ as val2]:
//          echo("Map pattern. key2: " + key2)
//      
//      case 17:
//          echo("Simple literal")
//      default:
//          echo("Default")
//    }
//  }
//  
//}
