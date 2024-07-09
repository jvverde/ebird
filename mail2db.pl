#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use DBI;
use DateTime::Format::Strptime; # For ISO-8601 formatting

# Variáveis para armazenar os argumentos da linha de comando
my $dbname;
my @filenames;

# Processar argumentos da linha de comando
GetOptions('db=s' => \$dbname) or die "Uso: $0 --db <nome_da_bd> <nome_do_ficheiro1> <nome_do_ficheiro2> ....<nome_do_ficheiroN>\n";

# Pegar os nomes dos arquivos restantes da linha de comando
@filenames = @ARGV;

# Verificar se ambos os argumentos foram fornecidos
die "Uso: $0 --db <nome_da_bd> <nome_do_ficheiro1> <nome_do_ficheiro2> ....<nome_do_ficheiroN>\n" unless $dbname && @filenames;

# Conectar ao banco de dados SQLite
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", "", "", {
    RaiseError => 1,
    AutoCommit => 1,
});

# Criar a tabela se ela não existir
my $tablename = 'sightings';
my $create_table_sql = qq{
    CREATE TABLE IF NOT EXISTS $tablename (
        name TEXT,
        sci_name TEXT,
        count INTEGER,
        date TEXT,
        author TEXT,
        location TEXT,
        map_url TEXT,
        PRIMARY KEY (name, date, author)
    )
};
$dbh->do($create_table_sql);

# Configuração do parser de data e hora
my $strp = DateTime::Format::Strptime->new(
    pattern   => '%b %d, %Y %H:%M', # Formato de entrada
    time_zone => 'floating',        # Fuso horário
);

# Processar cada arquivo de texto
foreach my $filename (@filenames) {
    open my $fh, '<', $filename or die "Não é possível abrir o ficheiro $filename: $!";

    local $/ = "\n\n"; # Modo de parágrafo, lê até uma linha em branco

    my $record = undef;

    while ($record = <$fh>) {
        die "'$filename' is not clean. Please use cleanmail.pl to remove the CR" if $record =~ /\r/;
        # Verificar se o registro é válido antes de começar a processar
        if ($record =~ /^(.+) \((.+)\) \(?(\d+)?\)?\s+- Reported (.+ \d{2}:\d{2}) by (.+)\s+- (.+)\s+- Map: (http:\/\/.+)$/m) {
            last;
        }
    }

    while (1) { 
        chomp $record;

        # Extrair a informação do registro
        if ($record =~ /^(.+) \((.+)\) \(?(\d+)?\)?.*?\n\s*- Reported (.+ \d{2}:\d{2}) by (.+)\s*?\n\s*- (.+)\s*?\n\s*- Map: (http:\/\/[^\s]+)/m) {
            my ($species_name, $scientific_name, $count, $datetime, $author, $location, $map_url) = ($1, $2, $3 // 1, $4, $5, $6, $7);

            # Parse da data e hora
            my $dt = $strp->parse_datetime($datetime);
            
            # Formatar a data e hora para ISO-8601
            my $iso_datetime = $dt->datetime(); # Retorna uma string ISO-8601

            # Inserir no banco de dados
            my $insert_sql = qq{
                INSERT OR IGNORE INTO $tablename (name, sci_name, count, date, author, location, map_url)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            };
            my $sth = $dbh->prepare($insert_sql);
            $sth->execute($species_name, $scientific_name, $count, $iso_datetime, $author, $location, $map_url);

            #print "Registro inserido: $species_name, $scientific_name, $count, $iso_datetime, $author, $location, $map_url\n";
        } else {
            last if $record =~ /^\s*[*]+\s*$/;
            warn "Registro inválido no arquivo $filename:\n++++++\n$record\n------\n";
        }
    } continue { $record = <$fh>; last unless defined $record }; # idea from https://stackoverflow.com/a/7899066

    close $fh;

    print "Dados do arquivo $filename inseridos no banco de dados com sucesso.\n";
}

$dbh->disconnect;

print "Processamento concluído.\n";
