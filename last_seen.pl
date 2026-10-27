#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use DBI;
use File::Spec;

my $species;
my $dir = 'dbs';
my ($dry, $help) = (0, 0);
my %opt;   # site, location, map: undef = coluna omitida; '' = coluna sem filtro

sub help_text {
    return <<"END_HELP";
Uso: $0 -e ESPÉCIE [opções]

Para cada grupo (espécie e, se pedidos, site, local e map) mostra a data
da última observação, o número de indivíduos dessa observação e o número
total de observações do grupo.

Opções:
  -e, --species NOME   Espécie (parcial, obrigatória)
  -s, --site [SITE]    Mostra a coluna site; com valor, filtra (parcial)
  -l, --location [LOC] Mostra a coluna location; com valor, filtra (parcial)
  -m, --map [URL]      Mostra a coluna map; com valor, filtra (parcial)
  -n, --dry-only       Apenas mostra a query SQL (não executa)
      --dir DIR        Diretório da _all.db (por omissão: ./dbs)
  -h, --help           Mostra esta ajuda

As colunas site, location e map só aparecem se a respetiva opção for
indicada, e o agrupamento só usa as colunas mostradas.

Exemplos:
  $0 -e Gull
  $0 -e Gull -s -l
  $0 -e "Kelp Gull" -s arica -l -m
  $0 -e Gull -s -l -n
END_HELP
}

GetOptions(
    'e|species=s'  => \$species,
    's|site:s'     => sub { $opt{site}     = $_[1] },
    'l|location:s' => sub { $opt{location} = $_[1] },
    'm|map:s'      => sub { $opt{map}      = $_[1] },
    'n|dry-only'   => \$dry,
    'dir=s'        => \$dir,
    'h|help'       => \$help,
) or die help_text();

if ($help) {
    print help_text();
    exit 0;
}

die help_text() if @ARGV || !defined $species || !length $species;

binmode STDOUT, ':encoding(UTF-8)';

# Colunas, por ordem: [site], name, ultima, individuos, observacoes, [location], [map]
# @grp = colunas de agrupamento (e de partição das funções de janela)
my (@sel, @grp, @hdr, %num);
my $i = 0;

if (defined $opt{site}) {
    push @sel, 'site'; push @grp, 'site'; push @hdr, 'site'; $i++;
}
push @sel, 'name'; push @grp, 'name'; push @hdr, 'name'; $i++;

push @sel, 'date AS ultima';        push @hdr, 'ultima';      $i++;
push @sel, 'count AS individuos';   push @hdr, 'individuos';  $num{$i++} = 1;
push @sel, 'observacoes';           push @hdr, 'observacoes'; $num{$i++} = 1;

for my $col (qw(location map)) {
    next unless defined $opt{$col};
    push @sel, $col; push @grp, $col; push @hdr, $col;
}

# WHERE: espécie sempre; os outros só se tiverem valor
my @where = ('name LIKE ?');
my @bind  = ("%$species%");
for my $col (qw(site location map)) {
    next unless defined $opt{$col} && length $opt{$col};
    push @where, "$col LIKE ?";
    push @bind,  "%$opt{$col}%";
}

# Partição = colunas de agrupamento; rn = 1 é a observação mais recente
my $part = join ', ', @grp;

my $sql = "WITH r AS (\n"
        . "  SELECT site, name, date, count, location, map,\n"
        . "         ROW_NUMBER() OVER (PARTITION BY $part\n"
        . "                            ORDER BY date DESC, count DESC, checklist) AS rn,\n"
        . "         COUNT(*) OVER (PARTITION BY $part) AS observacoes\n"
        . "  FROM sightings\n"
        . '  WHERE ' . join("\n    AND ", @where) . "\n"
        . ")\n"
        . 'SELECT ' . join(', ', @sel) . "\n"
        . "FROM r\n"
        . "WHERE rn = 1\n"
        . 'ORDER BY name, ultima' . join('', map { ", $_" } grep { $_ ne 'name' } @grp);

# --dry-only: mostra a query com os valores substituídos e termina
if ($dry) {
    my @b = @bind;
    (my $q = $sql) =~ s{\?}{ my $v = shift @b; $v =~ s/'/''/g; "'$v'" }ge;
    print "$q;\n";
    exit 0;
}

my $db = File::Spec->catfile($dir, '_all.db');
-f $db or die "BD '$db' não encontrada.\n";

my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "", {
    RaiseError     => 1,
    AutoCommit     => 1,
    sqlite_unicode => 1,
});

my $rows = $dbh->selectall_arrayref($sql, undef, @bind);
$dbh->disconnect;

unless (@$rows) {
    print "Sem resultados.\n";
    exit 0;
}

# Imprime uma tabela com larguras ajustadas; %$num marca colunas numéricas.
# A última coluna, se for texto, não leva espaços à direita.
sub print_table {
    my ($hdr, $data, $num) = @_;
    my @w = map { length } @$hdr;
    for my $r (@$data) {
        for my $c (0 .. $#$r) {
            my $l = length($r->[$c] // '');
            $w[$c] = $l if $l > $w[$c];
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

print_table(\@hdr, $rows, \%num);
