const _ = require('lodash');

const renameKey = (key) => {
   return _.replace(key, /[-.]/g, '_');
}

module.exports = { renameKey }