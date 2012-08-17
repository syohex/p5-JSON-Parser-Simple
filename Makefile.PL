use inc::Module::Install;
use Module::Install::AuthorTests;
use Module::Install::Repository;

name 'JSON-Parser-Simple';
all_from 'lib/JSON/Parser/Simple.pm';

author_tests('xt');
auto_set_repository();
WriteAll;
