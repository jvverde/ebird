#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use DBI;
use File::Spec;

# Uso: merge_dbs.pl [--dir <diretório>]    (por omissão: ./dbs)
my $dir = 'dbs';
GetOptions('dir=s' => \$dir)
    or die "Uso: $0 [--dir <diretório>]\n";

-d $dir or die "Diretório '$dir' não existe.\n";

my $all_name = '_all.db';
my $all_path = File::Spec->catfile($dir, $all_name);
my $tmp_path = "$all_path.tmp";

# Procurar todas as BDs (*.db), exceto a _all.db
opendir my $dh, $dir or die "Não é possível abrir '$dir': $!\n";
my @sources = sort grep { /\.db$/ && $_ ne $all_name && -f File::Spec->catfile($dir, $_) } readdir $dh;
closedir $dh;

die "Nenhuma BD encontrada em '$dir'.\n" unless @sources;

# Reconstruir de raiz num ficheiro temporário (garante que a _all.db
# reflete sempre o estado atual das BDs de origem, incluindo remoções)
unlink $tmp_path if -e $tmp_path;

my $dbh = DBI->connect("dbi:SQLite:dbname=$tmp_path", "", "", {
    RaiseError => 1,
    AutoCommit => 1,
});

$dbh->do(q{
    CREATE TABLE sightings (
        site      TEXT NOT NULL,   -- nome da BD de origem (sem .db)
        name      TEXT,
        sci_name  TEXT,
        count     INTEGER,
        date      TEXT,
        author    TEXT,
        location  TEXT,
        map       TEXT,
        checklist TEXT,
        PRIMARY KEY (site, name, date, author, checklist)
    )
});

my $total = 0;

for my $file (@sources) {
    my $path = File::Spec->catfile($dir, $file);
    #(my $site = $file) =~ s/\.db$//;
    (my $site = $file) =~ s/^ebird-|\.db$//g;
    
    my $n = eval {
        $dbh->do("ATTACH DATABASE ? AS src", undef, $path);

        my ($has) = $dbh->selectrow_array(
            q{SELECT COUNT(*) FROM src.sqlite_master WHERE type='table' AND name='sightings'}
        );
        die "tabela 'sightings' não existe\n" unless $has;

        $dbh->begin_work;
        my $rows = $dbh->do(q{
            INSERT OR IGNORE INTO sightings
                (site, name, sci_name, count, date, author, location, map, checklist)
            SELECT ?, name, sci_name, count, date, author, location, map, checklist
            FROM src.sightings
        }, undef, $site);
        $dbh->commit;
        $rows;
    };
    if ($@) {
        my $err = $@;
        eval { $dbh->rollback } unless $dbh->{AutoCommit};
        warn "Aviso: '$file' ignorada: $err";
    } else {
        $n = 0 if $n eq '0E0';
        printf "%-30s %6d registos\n", $site, $n;
        $total += $n;
    }
    eval { $dbh->do("DETACH DATABASE src") };
}

# Índices úteis para consultas
$dbh->do("CREATE INDEX idx_sightings_site ON sightings(site)");
$dbh->do("CREATE INDEX idx_sightings_name ON sightings(name)");
$dbh->do("CREATE INDEX idx_sightings_date ON sightings(date)");

$dbh->disconnect;

# Substituir a _all.db anterior de forma atómica
rename $tmp_path, $all_path or die "Não foi possível criar '$all_path': $!\n";

print "Total: $total registos de ", scalar(@sources), " BDs em $all_path\n";