## Name

Dump::Krumo - Fancy, colorful, human readable dumps of your data

## Synopsis

```perl
use Dump::Krumo;

my $data = { one => 1, two => 2, three => 3 };
kx($data);

my $list = ['one', 'two', 'three', 'four'];
kxd($list);
```

## Description

Colorfully dump your data to make debugging variables easier. `Dump::Krumo`
focuses on making your data human readable and easily parseable.

## Screenshots

<img width="1072" height="942" alt="image" src="https://github.com/user-attachments/assets/970932a4-21cb-4add-bf9d-f4a007435181" />

## Methods

- **kx($var)**

    Debug print `$var`.

- **kxd($var)**

    Debug print `$var` and `die()`. This outputs file and line information.

## Options

- `$Dump::Krumo::use_color = 1`

    Turn color on/off.

    - Setting to `0` disables color
    - Setting to `1` enables color for interactive shells (smart detection)
    - Setting to `2` forces color to be enabled

- `$Dump::Krumo::return_string = 0`

    Return a string instead of printing out

- `$Dump::Krumo::indent_spaces = 2`

    Number of spaces to indent each level

- `$Dump::Krumo::disable = 0`

    Disable all output from `Dump::Krumo`. This allows you to leave all of your
    debug print statements in your code, and disable them at runtime as needed.

- `$Dump::Krumo::promote_bool = 1`

    Convert JSON::PP::Booleans to true/false instead of treating them as objects.

- `$Dump::Krumo::stack_trace = 0`

    When `kxd()` is called it will dump a full stack trace.

- `$Dump::Krumo::highlight_ansi = 1`

    Colorize and make visible ANSI escape sequences

- `$Dump::Krumo::short_hex = 0`

    Use shorter hex syntax for strings with unpritable characters. By default we
    print `\x{01}\x\{02}\x{03}`, but with short\_hex enabled we print without
    braces instead: `\x01\x02\x03`.

- `$Dump::Krumo::COLORS`

    Reference to a hash of colors for each variable type. Update this and create
    your own color scheme.

## See Also

- [Data::Dumper](https://metacpan.org/pod/Data%3A%3ADumper)
- [Data::Dump](https://metacpan.org/pod/Data%3A%3ADump)
- [Data::Dump::Color](https://metacpan.org/pod/Data%3A%3ADump%3A%3AColor)
- [Data::Printer](https://metacpan.org/pod/Data%3A%3APrinter)

## Author

Scott Baker - [https://www.perturb.org/](https://www.perturb.org/)
