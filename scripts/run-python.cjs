const { spawnSync } = require('node:child_process');

const executable = process.platform === 'win32' ? 'python' : 'python3';
const result = spawnSync(executable, process.argv.slice(2), {
  stdio: 'inherit',
});

if (result.error) {
  console.error(`Unable to run ${executable}: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
