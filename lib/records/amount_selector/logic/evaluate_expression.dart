// ignore_for_file: prefer_single_quotes

enum CalculatorOperator {
  add('+'),
  subtract('-'),
  multiply('X'),
  divide('÷');

  final String symbol;

  const CalculatorOperator(this.symbol);

  @override
  String toString() {
    return symbol;
  }

  static CalculatorOperator? fromString(String symbol) {
    switch (symbol) {
      case '+':
        return CalculatorOperator.add;
      case '-':
        return CalculatorOperator.subtract;
      case '*':
      case 'x':
      case 'X':
      case '×': // Added the math symbol version just in case
        return CalculatorOperator.multiply;
      case '/':
      case '÷':
        return CalculatorOperator.divide;
      default:
        return null;
    }
  }

  double apply(double a, double b) {
    switch (this) {
      case CalculatorOperator.add:
        return a + b;
      case CalculatorOperator.subtract:
        return a - b;
      case CalculatorOperator.multiply:
        return a * b;
      case CalculatorOperator.divide:
        return a / b;
    }
  }

  static bool exprHasOperator(String expression) {
    expression = expression.trim();

    for (int i = 1; i < expression.length; i++) {
      // Start by zero to avoid returning true when the first number is negative
      final char = expression[i];
      if (CalculatorOperator.fromString(char) != null) {
        return true;
      }
    }

    return false;
  }

  static bool isOperator(String char) {
    if (char.length > 1) {
      throw ArgumentError("Character can not have this legth");
    }

    return CalculatorOperator.fromString(char) != null;
  }

  static bool exprEndsWithOperator(String expression) {
    if (expression.isEmpty) {
      return false;
    }

    final lastChar = expression[expression.length - 1];
    return CalculatorOperator.fromString(lastChar) != null;
  }

  static Iterable<String> getAllSymbols() {
    return values.map((op) => op.symbol);
  }
}

List<String> splitExprByNumbersAndOperator(String expression) {
  final operators = CalculatorOperator.getAllSymbols().join("|\\");
  // ignore: prefer_interpolation_to_compose_strings
  return RegExp(
    r'(\d+\.?\d*|\' + operators + ')',
  ).allMatches(expression).map((m) => m.group(0)!).toList();
}

double evaluateExpression(String expression) {
  // Remove any whitespace from the input string
  expression = expression.replaceAll(' ', '');

  // Handle negative sign at the start of the expression
  if (expression.startsWith('-')) {
    expression =
        '0$expression'; // Prepend 0 to allow for correct parsing, e.g., "-3+4" becomes "0-3+4"
  }

  // Ignore trailing operators by removing them if present
  while (expression.isNotEmpty &&
      CalculatorOperator.fromString(expression[expression.length - 1]) !=
          null) {
    expression = expression.substring(0, expression.length - 1);
  }

  if (expression.isEmpty) {
    throw ArgumentError('Invalid expression: no numbers found.');
  }

  final tokens = splitExprByNumbersAndOperator(expression);

  List<String> postfix = _infixToPostfix(tokens);
  return _evaluatePostfix(postfix);
}

List<String> _infixToPostfix(List<String> tokens) {
  final precedence = {
    CalculatorOperator.add: 1,
    CalculatorOperator.subtract: 1,
    CalculatorOperator.multiply: 2,
    CalculatorOperator.divide: 2,
  };
  final operators = <CalculatorOperator>[];
  final output = <String>[];

  for (int i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    final op = CalculatorOperator.fromString(token);

    if (double.tryParse(token) != null) {
      // If the token is a number, add it to the output
      output.add(token);
    } else if (op != null) {
      // While the top of the operator stack has the same or greater precedence
      while (operators.isNotEmpty &&
          precedence[operators.last]! >= precedence[op]!) {
        output.add(operators.removeLast().toString());
      }
      // Push the current operator to the stack
      operators.add(op);
    }
  }

  // Pop any remaining operators onto the output
  while (operators.isNotEmpty) {
    output.add(operators.removeLast().toString());
  }

  return output;
}

double _evaluatePostfix(List<String> postfix) {
  final stack = <double>[];

  for (final token in postfix) {
    if (double.tryParse(token) != null) {
      stack.add(double.parse(token));
    } else {
      final b = stack.removeLast();
      final a = stack.removeLast();
      final op = CalculatorOperator.fromString(token)!;
      stack.add(op.apply(a, b));
    }
  }

  return stack.last;
}
