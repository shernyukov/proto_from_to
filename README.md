# Proto_From_To.pl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Perl script for bidirectional rsync-based folders/files synchronization between Linux hosts. The script is suitable for fast mirroring with one command.
Uses the current directory as a reference point for synchronization and for simplicity and convenience, the remotehostname and direction are extracted from the script name (or symbolic link name).
If path mappings are not specified, the directory on the host will be on the same path as on local.<br/>
    e.g.<br/><br/>
     ``` to_remotehostname [files/dirs] ```   → sync TO host 'hostname' current directory or only files/dirs in the current directory<br/>
     ``` from_remotehostname [files/dirs]```  → sync FROM host 'hostname' current directory or only files/dirs in the current directory<br/><br/>

It is highly recommended to set up SSH key authentication.<br/>

Features:<br/>
✓ Preserves directory structure<br/>
✓ Simple INI-configuration (optional)<br/>
✓ Profile-based path mappings (optional)<br/>
✓ Progress synchronization<br/>
✓ Сhecks for presence and location in the current directory<br/>
✓ Save history to a log file on both local and remote hosts<br/>

## Installation
1. Clone the repo:
   ```bash
   git clone https://github.com/shernyukov/proto_from_to.git
   cd proto_from_to
   ```
2. if necessary, change the path to rsync at the beginning of the script:
   ```
   ...
   my $rsync_x = '/usr/bin/rsync';
   ...
   ```
4. Make executable:
   ```bash
   chmod +x proto_from_to.pl
   ```
5. Create symbolic links for your hosts in your executable directory:
   ```bash
   ln -s proto_from_to.pl to_servername
   ln -s proto_from_to.pl from_servername
   ```
## BASIC OPERATION:
  It is highly recommended to set up SSH key authentication.<br/>
  <ul>
      <li>Without arguments:&nbsp;&nbsp;&nbsp;&nbsp;Sync current directory TO remotehost or FROM remotehost<br>
      <li>With file/dir args:&nbsp;&nbsp;&nbsp;&nbsp;Sync TO or FROM remotehost only specified items (must be in current dir)<br>
  </ul>

## Configuration (optional)
Edit `~/.proto_from_to.conf`:
```ini
; servername conf:
[servername]
profiles = default, backup

[servername:default]
path_mapping = /local/path/project:/remote/path/product/

[servername:backup]
user = backup
path_mapping = /home:/backup/home , /opt:/backup/opt

; server2 conf:
...

```

## Usage
  ```bash
  # Sync current dir TO servername recursively (using the default profile if there is one)
  to_servername -r

  # Sync specific files/folders TO servername (profile 'backup')
  to_servername -u=backup file1.txt dir/

  # Sync current dir FROM servername recursively
  from_servername -r

  # Skip confirmations
  to_servername -r -y
  ```

## Options
| Flag            | Description                          |
|-----------------|--------------------------------------|
| `-h`            | Show help message                    |
| `-u=PROFILE`    | Use specific config profile          |
| `-y`            | Skip confirmation prompts            |
| `-r`            | Recursive sync                       |
| `-debug`        | Enable debug output                  |
| `-nocolor`      | Disable colored output               |
| `-print_config` | Show example config                  |
| `-rsync_opt=opt`| Options for rsync                    |
| `-l`            | List remote dir                      |


---

## License
MIT © Andrey Shernyukov
