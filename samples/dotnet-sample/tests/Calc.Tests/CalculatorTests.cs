using Calc;
using Xunit;

namespace Calc.Tests;

public class CalculatorTests
{
    [Fact]
    public void Factorial_of_five_is_120() => Assert.Equal(120, Calculator.Factorial(5));

    [Fact]
    public void Divide_by_zero_throws() => Assert.Throws<DivideByZeroException>(() => Calculator.Divide(1, 0));
}
