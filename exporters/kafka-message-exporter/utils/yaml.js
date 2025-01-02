const jsYaml = require('js-yaml');
const fs = require('fs');

const yamlToJSON = (path) => {
    const rulesFile = fs.readFileSync(path, { encoding: 'utf-8' });
    const rulesInJSON = jsYaml.load(rulesFile);
    return rulesInJSON || [];
}

module.exports = { yamlToJSON }