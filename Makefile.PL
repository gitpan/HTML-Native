use inc::Module::Install;

name "HTML-Native";
all_from "lib/HTML/Native.pm";
license "gpl_2";
build_requires "Test::More";
build_requires "Test::Exception";

requires "Carp";
requires "Carp::Clan";
requires "Exporter";
requires "HTML::Entities";
requires "List::Util";
requires "Scalar::Util";

WriteAll;
