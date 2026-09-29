import net from 'node:net';
import os from 'node:os';
import path from 'node:path';

const socketPath = path.join(os.homedir(), '.local', 'share', 'end-dots-martins', 'chrome-control.sock');
const input = process.argv[2] ? JSON.parse(process.argv[2]) : JSON.parse(await new Promise(resolve => {
  let s = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', c => s += c);
  process.stdin.on('end', () => resolve(s));
}));
const client = net.connect(socketPath);
let output = '';
client.on('connect', () => client.write(JSON.stringify(input) + '\n'));
client.on('data', chunk => output += chunk.toString());
client.on('end', () => { process.stdout.write(output); try { if (!JSON.parse(output).ok) process.exitCode = 1; } catch { process.exitCode = 1; } });
client.on('error', error => { console.error(error.message); process.exitCode = 1; });
