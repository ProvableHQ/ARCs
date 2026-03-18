const WrappedCredits = require('./contract');

const PRIVATE_KEY = process.env.PRIVATE_KEY || 'APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH';

async function run() {
  const c = new WrappedCredits({ privateKey: PRIVATE_KEY });

  console.log('Deploying program (via leo or Provable SDK fallback)...');
  try {
    const d = await c.deploy();
    console.log('Deploy output:', d.stdout || d);
  } catch (e) {
    console.error('Deploy failed:', e.stderr || e);
    process.exit(2);
  }

  console.log('Running basic flow: deposit -> transfer -> withdraw (approximate)');

  try {
    console.log('-- deposit_credits_public 1000');
    await c.execute('deposit_credits_public', '1000u64');
  } catch (e) {
    console.error('deposit failed:', e.stderr || e);
  }

  try {
    console.log('-- transfer_public ADDRESS 100');
    // replace ADDRESS with a real address if needed via env var
    const ADDRESS2 = process.env.ADDRESS2 || 'aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t';
    await c.execute('transfer_public', ADDRESS2, '100u128');
  } catch (e) {
    console.error('transfer failed:', e.stderr || e);
  }

  try {
    console.log('-- withdraw_credits_public 200');
    await c.execute('withdraw_credits_public', '200u64');
  } catch (e) {
    console.error('withdraw failed:', e.stderr || e);
  }

  console.log('JS tests finished. Note: this is a lightweight harness; integrate Provable SDK for richer tests.');
}

run().catch((e) => {
  console.error('Test runner uncaught error:', e);
  process.exit(1);
});
