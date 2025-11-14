# NAME

Dump::Krumo - Fancy, colorful, human readable dumps of your data

# SYNOPSIS

```perl
use Dump::Krumo;

my $data = { one => 1, two => 2, three => 3 };
kx($data);

my $list = ['one', 'two', 'three', 'four'];
kxd($list);
```

# DESCRIPTION

Colorfully dump your data to make debugging variables easier. `Dump::Krumo`
focuses on making your data human readable and easily parseable.

# SCREENSHOTS

<img width="1095" height="878" alt="dk-ss" src="https://github.com/user-attachments/assets/b7138f3d-3144-4b1a-a063-9ca445dd34d4" />

# METHODS

- **kx($var)**

    Debug print `$var`.

- **kxd($var)**

    Debug print `$var` and `die()`. This outputs file and line information.

# OPTIONS

- `$Dump::Krumo::use_color = 1`

    Turn on/off color

- `$Dump::Krumo::return_string = 0`

    Return a string instead of printing out

- `$Dump::Krumo::indent_spaces = 2`

    Number of spaces to indent each level

- `$Dump::Krumo::disable = 0`

    Disable all output from `Dump::Krumo`. This allows you to leave all of your
    debug print statements in your code, and disable them at runtime as needed.

# SEE ALSO

- [Data::Dumper](https://metacpan.org/pod/Data%3A%3ADumper)
- [Data::Dump](https://metacpan.org/pod/Data%3A%3ADump)
- [Data::Dump::Color](https://metacpan.org/pod/Data%3A%3ADump%3A%3AColor)
- [Data::Printer](https://metacpan.org/pod/Data%3A%3APrinter)

# AUTHOR

Scott Baker - [https://www.perturb.org/](https://www.perturb.org/)
