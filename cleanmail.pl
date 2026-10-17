#!/usr/bin/perl
use strict;
use warnings;
#binmode(STDOUT, ':utf8');
#binmode(STDIN, ':utf8');

use MIME::QuotedPrint;  # This module helps with decoding quoted-printable strings

# Verificar se pelo menos um argumento foi fornecido
@ARGV or die "Uso: $0 <nome_do_ficheiro1> <nome_do_ficheiro2> ...\n";

# Processar cada arquivo fornecido como argumento
foreach my $filename (@ARGV) {
    next if ($filename =~ /\.clean$/);
    # Abrir o arquivo para leitura
    open my $fh, '<', $filename or die "Não é possível abrir o ficheiro $filename: $!";
    
    # Ler o conteúdo do arquivo
    my $content = do { local $/; <$fh> };
    close $fh;

    # Decodificar quoted-printable encoding
    $content = decode_qp($content);

    my $output_filename = $filename . '.clean';
    next if (-e $output_filename && -s $output_filename);
    # Sobrescrever o arquivo original com o conteúdo processado
    open my $out_fh, '>', $output_filename or die "Não é possível abrir o ficheiro $output_filename para escrita: $!";
    print $out_fh $content;
    close $out_fh;

    print "Conteúdo quoted-printable decodificado no arquivo $filename com sucesso para $output_filename.\n";
}
