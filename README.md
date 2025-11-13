# NAME

Dump::Krumo - Fancy, colorful, human readable dumps of your data

# SYNOPSIS

    use Random::Simple;

    my $data = { one => 1, two => 2, three => 3 };
    kx($data);

    my $list = ['one', 'two', 'three', 'four'];
    kx($list);

# DESCRIPTION

Colorfully dump your data to make debugging your variables easier.
`Dump::Krumo` focuses on making your data human readable and easily parseable.

# METHODS

- **kx($var)**

    Debug print `$var`

- **kxd($var)**

    Debug print `$var` and `die()`.

# OPTIONS

- `$Dump::Krumo::use_color = 1`

    Turn on/off color

- `$Dump::Krumo::return_string = 0`

    Return a string instead of printing out

- `$Dump::Krumo::indent_spaces = 2`

    Number of spaces to indent each level

# SEE ALSO

- [Data::Dumper](https://metacpan.org/pod/Data%3A%3ADumper)
- [Data::Dump](https://metacpan.org/pod/Data%3A%3ADump)
- [Data::Dump::Color](https://metacpan.org/pod/Data%3A%3ADump%3A%3AColor)
- [Data::Printer](https://metacpan.org/pod/Data%3A%3APrinter)

# AUTHOR

Scott Baker - [https://www.perturb.org/](https://www.perturb.org/)
