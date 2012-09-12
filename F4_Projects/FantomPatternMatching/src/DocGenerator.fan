
using fandoc

class DocGenerator
{
  Void main()
  {
    parser := FandocParser()
    
    
    doc := parser.parse("pattern_doc.html", 
      `doc/Copy of Pattern matching in switch proposal.txt`.toFile.in)
    
//    echo(parser.errs)
    
    writer := HtmlDocWriter(`doc/Pattern matching in switch proposal.xhtml`.toFile.out)
    
    doc.write(writer)
  }
}
