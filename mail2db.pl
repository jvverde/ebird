#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use DBI;
use DateTime::Format::Strptime; # For ISO-8601 formatting

# Variáveis para armazenar os argumentos da linha de comando
my ($dbname, @filenames);

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
        map TEXT,
        checklist TEXT, -- Adicionando checklist como parte da chave primária
        PRIMARY KEY (name, date, author, checklist)
    )
};
$dbh->do($create_table_sql);

# Configuração do parser de data e hora
my $strp = DateTime::Format::Strptime->new(
    pattern   => '%b %d, %Y %H:%M', # Formato de entrada
    time_zone => 'floating',        # Fuso horário
);

#my $re = qr/^(.+) \((.+)\) (?:\((\d+)\))?.*?\n\s*- Reported (.+ \d{2}:\d{2}) by (.+)\s*?\n\s*- (.+)\s*?\n\s*- Map: (http:\/\/[^\s]+)\s*?\n\s*- Checklist: (https:\/\/ebird.org\/checklist\/[^\s]+)/m;
my $re = qr/^(.+) \(([A-Z][a-z]+ [a-z]+)[^\d]*\)(?: \((\d+)\))?.*\n\s*- Reported (.+ \d{2}:\d{2}) by (.+)\s*?\n\s*- (.+)\s*?\n\s*- Map: (http:\/\/[^\s]+)\s*?\n\s*- Checklist: (https:\/\/ebird.org\/checklist\/[^\s]+)/m;

# Processar cada arquivo de texto
FILE: foreach my $filename (@filenames) {
    open my $fh, '<', $filename or die "Não é possível abrir o ficheiro $filename: $!";

    local $/ = "\n\n"; # Modo de parágrafo, lê até uma linha em branco

    my $record = undef;

    while ($record = <$fh>) {
        warn "'$filename' is not clean. Please use cleanmail.pl to remove the CR" and next FILE if $record =~ /\r/;
        # Verificar se o registro é válido antes de começar a processar
        last if $record =~ $re;
    }

    while (1) { 
        chomp $record;

        # Extrair a informação do registro
        if ($record =~ $re) {
            my ($species_name, $scientific_name, $count, $datetime, $author, $location, $map, $checklist) = ($1, $2, $3 // 1, $4, $5, $6, $7, $8);
            
            # Parse da data e hora
            my $dt = $strp->parse_datetime($datetime);
            
            # Formatar a data e hora para ISO-8601
            my $iso_datetime = $dt->datetime(); # Retorna uma string ISO-8601

            # Inserir no banco de dados
            my $insert_sql = qq{
                INSERT OR IGNORE INTO $tablename (name, sci_name, count, date, author, location, map, checklist)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            };
            my $sth = $dbh->prepare($insert_sql);
            $sth->execute($species_name, $scientific_name, $count, $iso_datetime, $author, $location, $map, $checklist);

            # Mensagem por cada registro inserido
            # print "Registro inserido: $species_name, $scientific_name, $count, $iso_datetime, $author, $location, $map, $checklist\n";
        } else {
            last if $record =~ /^\s*[*]+\s*$/;
            # Registro inválido
            warn "Registro inválido no arquivo $filename:\n++++++\n$record\n------\n";
        }
    } continue { $record = <$fh>; last unless defined $record };  # idea from https://stackoverflow.com/a/7899066

    close $fh;

    print "Dados do arquivo $filename inseridos no banco de dados com sucesso.\n";
}

$dbh->disconnect;

print "Processamento concluído.\n";
