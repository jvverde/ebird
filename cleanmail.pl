#!/usr/bin/perl
use strict;
use warnings;

use MIME::QuotedPrint;  # This module helps with decoding quoted-printable strings

# Verificar se pelo menos um argumento foi fornecido
@ARGV or die "Uso: $0 <nome_do_ficheiro1> <nome_do_ficheiro2> ...\n";

# Processar cada arquivo fornecido como argumento
foreach my $filename (@ARGV) {
    # Abrir o arquivo para leitura
    open my $fh, '<', $filename or die "Não é possível abrir o ficheiro $filename: $!";
    
    # Ler o conteúdo do arquivo
    my $content = do { local $/; <$fh> };
    close $fh;

    # Decodificar quoted-printable encoding
    $content = decode_qp($content);

    # Sobrescrever o arquivo original com o conteúdo processado
    open my $out_fh, '>', $filename or die "Não é possível abrir o ficheiro $filename para escrita: $!";
    print $out_fh $content;
    close $out_fh;

    print "Conteúdo quoted-printable decodificado no arquivo $filename com sucesso.\n";
}
