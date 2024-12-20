
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms))
async function main(args) {
  await sleep(20 * 1000) // Sleep for 20 seconds

  return {
    body: `Hello, ${args.name || "World!"}`
  }
}
