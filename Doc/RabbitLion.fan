
class RabitLion
{
  
  Void encounter1(Forest forest)
  {
    switch (forest) {
      case Forest{fst = Lion{} as l; snd = Rabbit{} as r}:
        l.eat(r)
      case Forest{fst = Lion{} as l1; snd = Lion{} as l2}:
        l1.fight(l2)
      case Forest{fst = Rabbit{} as r1; snd = Rabbit{} as r2}:
        r1.mate(r2)
      case Forest{fst = Rabbit{} as r; snd = Lion{} as l}:
        r.fleeFrom(l)
    }
  }
  
  Void encounter2(Animal a1, Animal a2)
  {
    switch ([animal1, animal2]) {
      case [Lion{}   as l,  Rabbit{} as r]:
        l.eat(r)
      case [Lion{}   as l1, Lion{}   as l2]:
        l1.fight(l2)
      case [Rabbit{} as r1, Rabbit{} as r2]:
        r1.mate(r2)
      case [Rabbit{} as r,  Lion{}   as l]:
        r.flee(l)
      }
  } 
    
  Void encounterIf(Animal a1, Animal a2)
  {
    if (a1 is Lion) {
      if (a2 is Lion) {
        a1.fight(a2)
      } else if (a2 is Rabbit) {
        a1.eat(a2)
      }
    } else if (a1 is Rabbit) {
      if (a2 is Lion) {
        a1.flee(a2)
      } else if (a2 is Rabbit) {
        a1.mate(a2)
      }
    }
  }
  
}

class Forest {
  Animal fst
  Animal snd
  
  new make(|This->Void| initer) {
    initer(this)
  }
}

class Animal {}
class Rabbit : Animal {}

class Lion : Animal {}

