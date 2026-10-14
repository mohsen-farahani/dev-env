namespace Calc;

public static class Calculator
{
    public static int Factorial(int n)
    {
        if (n < 0) throw new ArgumentOutOfRangeException(nameof(n), "n must be >= 0");
        var result = 1;
        for (var i = 2; i <= n; i++)
        {
            result *= i; // breakpoint target (loop)
        }
        return result;
    }

    public static int Divide(int a, int b) => a / b; // throws DivideByZeroException when b == 0
}
