# Proto_From_To.pl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Perl script for bidirectional rsync-based file synchronization between Linux hosts.<br/>
Hostname and direction is extracted from script name.<br/> 
    (e.g. 'to_hostname' → sync TO host 'hostname')<br/>

Features:<br/>
✓ Minimal dependencies<br/>
✓ Preserves directory structure<br/>
✓ Simple INI-configuration (optional)<br/>
✓ Profile-based path mappings (optional)<br/>

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
   ln -s proto_from_to.pl to_server1
   ln -s proto_from_to.pl from_server1
   ```
## BASIC OPERATION:

  Without arguments:&nbsp;&nbsp;&nbsp;&nbsp;Sync current directory<br>
  With file/dir args:&nbsp;&nbsp;&nbsp;&nbsp;Sync _TO_ only specified items (must be in current
                        dir)<br>


## Configuration (optional)
Edit `~/.proto_from_to.conf`:
```ini
; server1 conf:
[server1]
profiles = default, backup

[server1:default]
path_mapping = /local/path/project:/remote/path/product/

[server1:backup]
user = backup
path_mapping = /home:/backup/home , /opt:/backup/opt

; server2 conf:
...

```

## Usage
  ```bash
  # Sync current recursively dir TO server1 (using default profile)
  to_server1 -r

  # Sync specific files/folders TO server1 (profile 'backup')
  to_server1 -u=backup file1.txt dir/

  # Sync recursively FROM server1
  from_server1 -r

  # Skip confirmations
  to_server1 -r -y
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
