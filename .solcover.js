module.exports = {
    skipFiles: ['mock', 'vendor0.8'],
    configureYulOptimizer: true,
    mocha: {
        grep: "@skip-on-coverage", // Find everything with this tag
        invert: true               // Run the grep's inverse set.
    }
};