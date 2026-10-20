#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use DBI;
use File::Spec;

my ($match, $site, $days, $dir) = ('', '', 30, 'dbs');
my $location;   # undef = sem -l
my $loc_width;  # undef = sem limite
my ($by_species, $keep_variants, $no_map, $no_location, $help) = (0, 0, 0, 0, 0);

sub help_text {
    return <<"END_HELP";
Uso: $0 [opções]

Conta avistamentos na BD _all.db.

Opções:
  -m, --match NOME     Filtra pelo nome da espécie (parcial)
  -s, --site SITE      Filtra pelo site (BD de origem, parcial)
  -l, --location [LOC] Filtra pelo local (parcial), agrupa também por local e
                       map e mostra as colunas location e map; sem valor,
                       mostra todos os locais
      --no-map         Com -l: omite a coluna map (e não agrupa por map)
      --no-location    Com -l: omite a coluna location (e não agrupa por
                       location); o filtro de -l continua a aplicar-se
                       (--no-map e --no-location são mutuamente exclusivas)
      --loc-width N    Com -l: limita a coluna location a N caracteres (mínimo
                       4); os nomes mais compridos terminam em "..."
  -d, --days N         Últimos N dias (por omissão: 30)
  -g, --by-species     Agrupa por espécie (total decrescente, depois nome);
                       cada espécie tem uma linha por site (e local, com -l),
                       com o total e o nome repetidos e a contagem dessa linha
  -k, --keep-variants  Não junta nomes com informação extra entre parênteses
                       (por omissão "Kelp Gull (dominicanus)" conta como
                       "Kelp Gull")
      --dir DIR        Diretório da _all.db (por omissão: ./dbs)
  -h, --help           Mostra esta ajuda

Sem -g: ordenação por count (decrescente), site, local e nome.

Exemplos:
  $0 -m Gull
  $0 -m Gull -g
  $0 -m Gull -l
  $0 -m Gull -l Arica
  $0 -m Gull -l Arica --no-map
  $0 -m Gull -l --loc-width 40
  $0 -m Gull -l --no-location -g
  $0 -m Gull -l Arica -g -k
END_HELP
}

GetOptions(
    'm|match=s'       => \$match,
    's|site=s'        => \$site,
    'l|location:s'    => sub { $location = length $_[1] ? $_[1] : '%' },
    'no-map'          => \$no_map,
    'no-location'     => \$no_location,
    'loc-width=i'     => \$loc_width,
    'd|days=i'        => \$days,
    'g|by-species'    => \$by_species,
    'k|keep-variants' => \$keep_variants,
    'dir=s'           => \$dir,
    'h|help'          => \$help,
) or die help_text();

if ($help) {
    print help_text();
    exit 0;
}

die help_text() if @ARGV || $days < 0;

die "Erro: --no-map e --no-location são mutuamente exclusivas.\n"
    if $no_map && $no_location;
die "Erro: --no-map e --no-location só podem ser usadas com --location (-l).\n"
    if ($no_map || $no_location) && !defined $location;
if (defined $loc_width) {
    die "Erro: --loc-width só pode ser usada com --location (-l).\n"
        unless defined $location;
    die "Erro: --loc-width não pode ser usada com --no-location.\n"
        if $no_location;
    die "Erro: --loc-width tem de ser pelo menos 4.\n"
        if $loc_width < 4;
}

# Texto da BD descodificado (UTF-8), para que o corte e as larguras
# contem caracteres e não bytes; a saída é codificada em UTF-8
binmode STDOUT, ':encoding(UTF-8)';

my $db = File::Spec->catfile($dir, '_all.db');
-f $db or die "BD '$db' não encontrada.\n";

my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "", {
    RaiseError     => 1,
    AutoCommit     => 1,
    sqlite_unicode => 1,
});

# -l presente (com ou sem valor) ativa as colunas location e map,
# que podem ser omitidas individualmente com --no-location / --no-map.
# Só se agrupa pelas colunas que são mostradas.
my $by_loc   = defined $location ? 1 : 0;
my $show_loc = $by_loc && !$no_location;
my $show_map = $by_loc && !$no_map;
$location = '' unless defined $location;   # sem -l, o filtro não restringe nada

my $loc_expr = $show_loc ? 'location' : q{''};
my $map_expr = $show_map ? 'map'      : q{''};

# Nome da espécie: por omissão remove o sufixo " (...)"
my $species_expr = $keep_variants
    ? 'name'
    : q{CASE WHEN instr(name, ' (') > 1
             THEN substr(name, 1, instr(name, ' (') - 1)
             ELSE name END};

# O alias do map é map_col para não colidir com a coluna real "map"
my $rows = $dbh->selectall_arrayref(qq{
    SELECT COUNT(*) AS count, site, $loc_expr AS loc, $species_expr AS species,
           $map_expr AS map_col
    FROM sightings
    WHERE name     LIKE ?
      AND site     LIKE ?
      AND location LIKE ?
      AND date >= date('now', ?)
    GROUP BY site, loc, species, map_col
    ORDER BY count DESC, site ASC, loc ASC, species ASC, map_col ASC
}, undef, "%$match%", "%$site%", "%$location%", "-$days days");

$dbh->disconnect;

unless (@$rows) {
    print "Sem resultados.\n";
    exit 0;
}

# Corta o location para --loc-width caracteres (só na apresentação)
sub fit_loc {
    my ($s) = @_;
    return $s unless defined $loc_width && defined $s && length $s > $loc_width;
    return substr($s, 0, $loc_width - 3) . '...';
}

# Imprime uma tabela com larguras ajustadas; %$num marca colunas numéricas.
# A última coluna, se for texto, não leva espaços à direita.
sub print_table {
    my ($hdr, $data, $num) = @_;
    my @w = map { length } @$hdr;
    for my $r (@$data) {
        for my $i (0 .. $#$r) {
            my $l = length($r->[$i] // '');
            $w[$i] = $l if $l > $w[$i];
        }
    }
    my $fmt = join '  ', map {
        $num->{$_}  ? "%$w[$_]s"
      : $_ == $#w   ? '%s'
      :               "%-$w[$_]s"
    } 0 .. $#w;
    printf "$fmt\n", @$hdr;
    printf "$fmt\n", map { '-' x $_ } @w;
    printf "$fmt\n", map { $_ // '' } @$_ for @$data;
}

# Colunas opcionais, na ordem: location, map
my @extra_hdr = (($show_loc ? 'location' : ()), ($show_map ? 'map' : ()));

if ($by_species) {
    # Total por espécie e linhas por site/local/map (já em ordem count desc)
    my (%total, %parts);
    for my $r (@$rows) {
        my ($c, $s, $l, $n, $m) = @$r;
        $total{$n} += $c;
        push @{ $parts{$n} }, [ $s, $l, $c, $m ];
    }

    my @names = sort { $total{$b} <=> $total{$a} || $a cmp $b } keys %total;

    my @out;
    for my $n (@names) {
        for my $p (@{ $parts{$n} }) {
            my ($s, $l, $c, $m) = @$p;
            push @out, [ $total{$n}, $n, $s, $c,
                         ($show_loc ? fit_loc($l) : ()), ($show_map ? $m : ()) ];
        }
    }

    my @hdr = ('total', 'name', 'site', 'count', @extra_hdr);
    print_table(\@hdr, \@out, { 0 => 1, 3 => 1 });
}
else {
    my @out = map {
        my ($c, $s, $l, $n, $m) = @$_;
        [ $c, $s, $n, ($show_loc ? fit_loc($l) : ()), ($show_map ? $m : ()) ];
    } @$rows;

    my @hdr = ('count', 'site', 'name', @extra_hdr);
    print_table(\@hdr, \@out, { 0 => 1 });
}