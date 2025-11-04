ProFTPD module mod_readme ProFTPD module mod_readme This module is contained in the mod_readme.c file for
ProFTPD 1.3. x , and is not compiled by default.  Installation
instructions are discussed here . The most current version of mod_readme is distributed with the
ProFTPD source code. Directives DisplayReadme DisplayReadme Syntax: DisplayReadme path|pattern Default: None Context: server config, <VirtualHost> , <Global> , <Anonymous> Module: mod_readme Compatibility: 1.2.0pre8 and later The DisplayReadme directive configures the server to notify
the client of the last modified date of the specified path or pattern .  These notifications happen whenever a client logs in,
or whenever the client changes directory. For example: DisplayReadme README will result in the following being displayed to connecting client, assuming
there is a file called "README" in the current directory: Please read the file README
  it was last modified on Sun Oct 17 10:36:14 2011 - 0 days ago As another example, assume there are two files named "README" and
"README.first" in the directory into which the client changed.  Then using DisplayReadme README* might result in the following being sent to the client: Please read the file README
  it was last modified on Tue Jan 25 04:47:48 2011 - 0 days ago
  Please read the file README.first
  it was last modified on Tue Jan 25 04:48:04 2011 - 0 days ago Installation To install mod_readme , follow the usual steps for using
third-party modules in ProFTPD: $ ./configure --with-modules=mod_readme ... To build mod_readme as a DSO module: # ./configure --enable-dso --with-shared=mod_readme Then follow the usual steps: $ make 
  $ make install Alternatively, if your proftpd was compiled with DSO support,
you can use the prxs tool to build mod_readme as
a shared module: $ prxs -c -i -d mod_readme.c © Copyright 2011-2013 TJ Saunders All Rights Reserved