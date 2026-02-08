const { execFile } = require('child_process');
const path = require('path');

// Lightweight contract abstraction that prefers the Provable SDK when available,
// but falls back to invoking the `leo` CLI if the SDK is not installed.

let Provable = null;
try {
  Provable = require('@aleo/provable');
} catch (e) {
  Provable = null;
}

class WrappedCreditsContract {
  constructor(opts = {}) {
    this.leoPath = opts.leoPath || path.join(process.env.HOME || '~', 'programs', 'leo', 'target', 'release', 'leo');
    this.privateKey = opts.privateKey || process.env.PRIVATE_KEY || '';
    this.program = opts.program || 'wrapped_credits.aleo';
  }

  async deploy() {
    if (Provable) {
      throw new Error('Provable SDK deploy flow not implemented in this stub. Install the SDK and implement deployment using its API.');
    }
    return this._runLeo(['deploy', '--private-key', this.privateKey, '--devnet']);
  }

  async execute(fnName, ...args) {
    if (Provable) {
      throw new Error('Provable SDK execute flow not implemented in this stub. Install the SDK and implement calls using its API.');
    }
    const params = [fnName, ...args.map(String), '--private-key', this.privateKey];
    return this._runLeo(['execute', ...params]);
  }

  _runLeo(argArray) {
    return new Promise((resolve, reject) => {
      execFile(this.leoPath, argArray, { cwd: process.cwd() }, (err, stdout, stderr) => {
        if (err) {
          return reject({ err, stdout, stderr });
        }
        resolve({ stdout, stderr });
      });
    });
  }
}

module.exports = WrappedCreditsContract;
