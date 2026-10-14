using Calc;

var n = args.Length > 0 ? int.Parse(args[0]) : 5;
var fact = Calculator.Factorial(n); // breakpoint target (call site)
Console.WriteLine($"Factorial({n}) = {fact}");

if (args.Contains("--throw"))
{
    Console.WriteLine(Calculator.Divide(1, 0));
}
