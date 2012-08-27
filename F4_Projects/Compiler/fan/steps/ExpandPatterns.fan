
class ExpandPatterns : CompilerStep
{
  new make(Compiler compiler)
    : super(compiler)
  {
  }
  
  override Void run()
  {
    log.debug("ExpandPatterns")

    walk(compiler, VisitDepth.stmt)
  }
  
  Void dump( Obj? s ) {
    log.debug("ExpandPatterns.visitStmt: " + s)
  }
  
  override Void enterMethodDef(MethodDef def)
  {
    super.enterMethodDef(def)
    
    // TODO: Debug code, to be removed
    if (def.facets != null && def.facets.any {it.type.name == "DumpAstBefore"})
    {
      dump("enterMethodDef ------------------")
      def.dump
    }
  }

  override Void exitMethodDef(MethodDef def)
  {
    super.exitMethodDef(def)

    // TODO: Debug code, to be removed
    if (def.facets != null && def.facets.any {it.type.name == "DumpAstAfter"})
    {
      dump("exitMethodDef -------------------")
      def.dump
    }
  }
  
  
  override Stmt[]? visitStmt(Stmt stmt)
  {
    if (stmt.id != StmtId.switchStmt) return null
    
    swch := (SwitchStmt) stmt
    
    if (swch.cases.any { it.cases.any { isItBlockCtor(it) || it.id == ExprId.listLiteral } }) {
      log.info("Match switch found")
      return SwitchSubs(swch, this).run
    } else {
      return null
    }
  }
  
  static Bool isItBlockCtor(Expr expr)
  {
    return expr.id == ExprId.call && ((CallExpr) expr).method.isItBlockCtor
  }

}

internal class SwitchSubs
{
  // Variable that is set when a pattern has matched, and checked before trying the next
  // pattern
  private MethodVar? hasMatchedVar
  
  // Holds the value of evaluating the expression that is switched on
  private MethodVar? switchObjVar
  
  // The running compiler step
  private ExpandPatterns step

  // The original swich statment
  private SwitchStmt? swch
  
  // An ID nr for sub patterns variable names
  private Int objVarNr := 0
  
  new make(SwitchStmt swch, ExpandPatterns step)
  {
    this.step = step
    this.swch = swch
  }
  
  private Int nextId() {
    return objVarNr++
  }
  
  
  Void dump(Obj? s) {
    step.log.debug("SwitchSubs: " + s)
  }

  Stmt[] run()
  {
    // Set up hasMatched variable
    // TODO: Remove temp name
    hasMatchedVar = step.curMethod.addLocalVar(step.ns.boolType, "hasMatched", step.curMethod.code)
    hasMatchedStmt := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, hasMatchedVar),
      LiteralExpr.makeFalse(swch.loc, step.ns)).toStmt
    
    // Set up matchObj variable
    // TODO: Remove temp name
    switchObjVar = step.curMethod.addLocalVar(
      swch.condition.ctype, "switchObj", step.curMethod.code)
    switchObjStmt := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, switchObjVar), swch.condition).toStmt
    
    // Generate the acctual match logic
    matchCode := handleCases(swch.cases.ro)
    
    result := Stmt[hasMatchedStmt, switchObjStmt].addAll(matchCode)

    // Add a throws stmt is the switch would always exit
    if (swch.isExit)
    {
      result.add(ThrowStmt(swch.loc, 
        CallExpr.makeWithMethod(swch.loc, (Expr?)null, step.ns.errType.method("make"), 
          [LiteralExpr.makeStr(swch.loc, step.ns, "Unreachable code")])))
    }
    
    return result
  }

  **
  ** Recurses over all cases in a switch, returning test statments for each case. 
  ** 
  **  
  private Stmt[] handleCases(Case[] cases)
  {
    // Create hasMatched test
    hasMatchedTest := IfStmt(swch.loc,
            UnaryExpr(swch.loc,
                ExprId.boolNot, 
                Token.bang,
                LocalVarExpr(swch.loc, hasMatchedVar)), 
                Block(swch.loc)
              )

    // Base case: If all cases have been handled emit the default block and return
    if (cases.isEmpty) {
      if (swch.defaultBlock != null) {
        // If there is def block, test for has matched and emit def block
        hasMatchedTest.trueBlock = swch.defaultBlock
        return [hasMatchedTest]
      } else {
        return [,] // If no def block just return
      }
    }
    
    // Recursive case, handle first case, that handle rest in recursive call
    cse := cases.first
    
     // TODO: Handle multiple cases for one branch
    if (cse.cases.size > 1)
      throw step.err("Only one case allowed in pattern switches", cse.cases[1].loc)
    
    patternExpr := cse.cases.first

    hasMatchedTest.loc = cse.loc  // Set a more precise loc
    hasMatchedTest.trueBlock.loc = patternExpr.loc 
    
    // Make test for pattern in this case
    tests := makePatternTest(patternExpr, LocalVarExpr(swch.loc, switchObjVar), cse)
    
    // Add the branch code, and the hasMatch = true statement, if this isnt a return
    if (!cse.block.isExit)
    {
      tests.last.extSpot.add(
        ExprStmt(
          BinaryExpr.makeAssign(
              LocalVarExpr(swch.loc, hasMatchedVar),
              LiteralExpr.makeTrue(swch.loc, step.ns))))
    }

    // Add the branch code after the last test, when its known that there is a match 
    tests.last.extSpot.addAll(cse.block.stmts)

    // Put each test in the previous ones extSpot
    (0..tests.size-2).each |i| {
      tests[i].extSpot.addAll(tests[i+1].testStmts)
    }
    
    // Add all the tests in the has matched test (they are now in tests[0]) 
    hasMatchedTest.trueBlock.addAll(tests[0].testStmts)

    // Handle rest of cases
    hasMatchedTest.trueBlock.addAll(handleCases(cases[1..-1]))
    
    return [hasMatchedTest]
  }
  
  
  **
  ** Checks the kind of pattern and calls the corresponding method. Called recursivly
  ** for sub patterns. Returns test statement.
  **
  ** patternExpr: Expression describing the pattern
  ** matchObjExpr: Value to match against. Can only be used in one place, should be bould
  **    to var if used more times.
  ** cse: The current case branch
  **  
  private MatchTest[] makePatternTest(Expr patternExpr, Expr matchObjExpr, Case cse)
  {
    // Test for object pattern
    if (ExpandPatterns.isItBlockCtor(patternExpr))
      return makeCtorTest((CallExpr) patternExpr, matchObjExpr, cse)
    else if (patternExpr.id == ExprId.listLiteral)
      return makeListTest((ListLiteralExpr) patternExpr, matchObjExpr, cse)
    else
      return makeSimpleTest(patternExpr, matchObjExpr, cse)
  }

  private MatchTest[] makeListTest(ListLiteralExpr patternExpr, Expr matchObjExpr, Case cse)
  {
    // Create match object
    matchObjVar := step.curMethod.addLocalVar(patternExpr.ctype, null, step.curMethod.code)
    matchObjDef := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, matchObjVar),
      TypeCheckExpr(swch.loc, ExprId.asExpr, matchObjExpr, patternExpr.ctype)).toStmt
    
    // Test statement for if match obj is right type
    typeTest := IfStmt(patternExpr.loc,
      UnaryExpr(
        patternExpr.loc,
        ExprId.cmpNotNull,
        Token.notEq,
        LocalVarExpr(patternExpr.loc, matchObjVar)),
      Block(patternExpr.loc))

    // Test is match obj has same size as pattern
    sizeTest := IfStmt(patternExpr.loc,
      ShortcutExpr.makeBinary(
        FieldExpr( 
          patternExpr.loc, 
          LocalVarExpr(patternExpr.loc, matchObjVar),
          matchObjVar.ctype.field("size")),
        Token.eq,
        LiteralExpr(patternExpr.loc, ExprId.intLiteral, step.ns.intType, patternExpr.vals.size)),
      Block(patternExpr.loc))
    
    // Check all fields in the ctor clause
    tests := patternExpr.vals.map(|Expr expr, Int i -> MatchTest[]|
      {
        // Recursive call for sub pattern
        return makePatternTest(
          expr,
          ShortcutExpr.makeGet(expr.loc,
            LocalVarExpr(expr.loc, matchObjVar),
            LiteralExpr(expr.loc, ExprId.intLiteral, step.ns.intType, i)) {
              method = step.ns.listType.method(op.methodName)
              ctype = step.ns.objType
            },
          cse)
        
        return [,]
      }).flatten
    
    return [MatchTest([matchObjDef, typeTest], typeTest.trueBlock.stmts),
            MatchTest([sizeTest], sizeTest.trueBlock.stmts)]
      .addAll(tests)
  }
  
  private MatchTest[] makeSimpleTest(Expr patternExpr, Expr matchObjExpr, Case cse)
  {
    testStmt := IfStmt(
      patternExpr.loc,  
      ShortcutExpr(matchObjExpr, Token.eq, patternExpr) {
          method = step.ns.objType.method(ShortcutOp.eq.methodName)
//          method = patternExpr.ctype.operators.find(ShortcutOp.eq.methodName).first
        },
        Block(patternExpr.loc))

    return [MatchTest([testStmt], testStmt.trueBlock.stmts)]
  }

  **
  ** Returns test statements for object creation pattern
  ** 
  private MatchTest[] makeCtorTest(CallExpr ctorCall, Expr matchObjExpr, Case cse)
  {
    // Create match object
    matchObjVar := step.curMethod.addLocalVar(ctorCall.ctype, null, step.curMethod.code)
    matchObjDef := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, matchObjVar),
      TypeCheckExpr(swch.loc, ExprId.asExpr, matchObjExpr, ctorCall.ctype)).toStmt
    
    // Test statement for if match obj is right type
    typeTest := IfStmt(ctorCall.loc,  
      UnaryExpr(
        ctorCall.loc,
        ExprId.cmpNotNull,
        Token.notEq,
        LocalVarExpr(ctorCall.loc, matchObjVar)),
      Block(ctorCall.loc))
    
    // Get the member assignment expressions from the it block closure,
    // removing the return statment at the end.
    membs := ((((ctorCall.args.first as ClosureExpr).call.code.stmts.first as ExprStmt)
              .expr as CallExpr).method as MethodDef).code.stmts[0..-2]
    
    // Check all fields in the ctor clause
    tests := membs.map(|Stmt stmt -> MatchTest[]|
      {
        assignExpr := (stmt as ExprStmt).expr as BinaryExpr
        if (assignExpr == null || assignExpr.id != ExprId.assign)
          step.err("Only assignment exprs in patterns", stmt.loc)
        
        fieldExpr := assignExpr.lhs as FieldExpr
        
        // Recursive call for sub pattern
        return makePatternTest(
          assignExpr.rhs,
          FieldExpr(fieldExpr.loc, LocalVarExpr(fieldExpr.loc, matchObjVar), fieldExpr.field),
          cse)
      }).flatten

    return [MatchTest([matchObjDef, typeTest], typeTest.trueBlock.stmts)].addAll(tests)
  }
  
  static Obj? dummyInspect( Obj? o ) {
    return o
  }


}


class MatchTest {
  Stmt[] testStmts
  Stmt[] extSpot
  
  new make(Stmt[] test, Stmt[] extSpot) {
    this.testStmts = test
    this.extSpot = extSpot
  }
}



abstract class MatchSpec {
}

class ObjSpec : MatchSpec
{
  Type type
  MatchSpec[] members

  new make(|This -> Void| f) {
    f(this)
  }
}

class EqualsSpec : MatchSpec {
  Obj? obj
}
















