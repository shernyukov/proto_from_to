# Proto_From_To.pl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Perl script for bidirectional rsync-based folders/files synchronization between Linux hosts.<br/>
Uses the current directory as a reference point for synchronization and for simplicity and convenience, the hostname and direction are extracted from the script name (or symbolic link name).<br/>
If path mappings are not specified, the directory on the host will be on the same path as on local.<br/>
    e.g.<br/>
    'to_hostname [files/dirs]' → sync TO host 'hostname' current directory or only files/dirs in the current directory<br/>
    'from_hostname' → sync FROM host 'hostname' current directory<br/>

Features:<br/>
✓ Preserves directory structure<br/>
✓ Simple INI-configuration (optional)<br/>
✓ Profile-based path mappings (optional)<br/>
✓ Progress synchronization<br/>
✓ Minimal dependencies<br/>

## Installation
1. Clone the repo:
   ```bash
   git clone https://github.com/shernyukov/proto_from_to.git
   cd proto_from_to
   ```
2. Make executable:
   ```bash
   chmod +x proto_from_to.pl
   ```
3. Create symbolic links for your hosts in your executable directory:
   ```bash
   ln -s proto_from_to.pl to_servername
   ln -s proto_from_to.pl from_servername
   ```
## BASIC OPERATION:

  Without arguments:&nbsp;&nbsp;&nbsp;&nbsp;Sync current directory<br>
  With file/dir args:&nbsp;&nbsp;&nbsp;&nbsp;Sync _TO_ only specified items (must be in current
                        dir)<br>


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
  # Sync current recursively dir TO server1 (using default profile)
  to_servername -r

  # Sync specific files/folders TO server1 (profile 'backup')
  to_servername -u=backup file1.txt dir/

  # Sync recursively FROM server1
  from_servername -r

  # Skip confirmations
  to_servername -r -y
  ```

## Options
| Flag           | Description                          |
|----------------|--------------------------------------|
| `-h`           | Show help message                    |
| `-u=PROFILE`   | Use specific config profile          |
| `-y`           | Skip confirmation prompts            |
| `-r`           | Recursive sync                       |
| `-debug`       | Enable debug output                  |
| `-nocolor`     | Disable colored output               |
| `-print_config`| Show example config                  |
| `-rsync_opt`   | Options for rsync                    |


---

## License
MIT © Andrey Shernyukov
