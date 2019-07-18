var fs = require('fs');

function parseIOS(data) {

  const rgxKeyValue = /"(.*)"\s*=\s*"(.*)"/; 
  const rgxCommentSingle = /^\s*\/\/ ?(.*)/;
  const rgxCommentBlock = /^\s*\/\* ?(.*?) ?\*\//; 
  const rgxCommentStart = /^\s*\/\* ?(.*)/;
  const rgxCommentEnd = /(.*?) ?\*\//; 

  let lines = data.trim().split('\n');
  let parsed = [];
  let multilineComment = false;
  

  for (let line of lines) {
    let kv = line.match(rgxKeyValue);
    if (kv != null) {
      parsed.push([kv[1], kv[2].replace(/\\"/g, '"').replace(/\\t/g, '\t').replace(/\\r/g, '\r').replace(/\\n/g, '\n').replace(/\\\\/g, '\\')]);
      continue;
    }
    
    let singleComment = line.match(rgxCommentSingle);
    if (singleComment) {
      parsed.push(singleComment[1]);
      continue;
    }
    
    let blockComment = line.match(rgxCommentBlock);
    if (blockComment) {
      parsed.push(blockComment[1]);
      continue;
    }
    
    let commentStart = line.match(rgxCommentStart);
    if (commentStart) {
      parsed.push(commentStart[1]);
      multilineComment = true;
      continue;
    }
    
    if (multilineComment) {
      let commentEnd = line.match(rgxCommentEnd);
      if (commentEnd) {
        parsed[parsed.length - 1] += '\n' + commentEnd[1];
        multilineComment = false;
      } else {
        parsed[parsed.length - 1] += '\n' + line;
      }
      continue;
    }
    
    if (/^\s*$/.test(line))
            parsed.push('');
  }
  
  return parsed;
}

function parseAndroid(data) {

  const rgxKeyValue = /<string name="(.*)">(.*)<\/string>/;
  const rgxCommentBlock = /<!-- ?(.*?) ?-->/;
  const rgxCommentStart = /<!-- ?(.*)/;
  const rgxCommentEnd = /(.*?) ?-->/;
  const rgxPluralsStart = /<plurals name="(.*)">/;
  const rgxPluralsEnd = /\s<\/plurals>/

  let lines = data.trim().split('\n');
  let result = {
    parsed: [],
    parsedPlurals: new Map()
  };

  let multilineComment = false;
  let pluralsDefinitionKey = null;

  for (let line of lines) {
    let kv = line.match(rgxKeyValue);
    if (kv != null) {
      result.parsed.push([kv[1], kv[2].replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&').replace(/\\t/g, '\t').replace(/\\r/g, '\r').replace(/\\n/g, '\n').replace(/\\\\/g, '\\')]);
      continue;
    }

    let blockComment = line.match(rgxCommentBlock);
    if (blockComment) {
      result.parsed.push(blockComment[1]);
      continue;
    } 

    let commentStart = line.match(rgxCommentStart);
    if (commentStart && !pluralsDefinition) {
      result.parsed.push(commentStart[1]);
      multilineComment = true;
      continue;
    }
    
    if (multilineComment) {
      let commentEnd = line.match(rgxCommentEnd);
      if (commentEnd) {
        result.parsed[result.parsed.length - 1] += '\n' + commentEnd[1];
        multilineComment = false;
      } else {
        result.parsed[result.parsed.length - 1] += '\n' + line;
      }
      continue;
    }

    let pluralsStart = line.match(rgxPluralsStart);
    if (pluralsStart) {
      pluralsDefinitionKey = pluralsStart[1];
      result.parsedPlurals.set(pluralsDefinitionKey, [ ]);
      continue;
    }

    if (pluralsDefinitionKey) {
      let pluralsEnd = line.match(rgxPluralsEnd) 
      if (pluralsEnd) {
        pluralsDefinitionKey = null
        continue;
      } else if (isEmpty(line)) {
        continue;
      } else {
        result.parsedPlurals.get(pluralsDefinitionKey).push(line);
      }
    }
    
    if (isEmpty(line))
            result.parsed.push('');
  }
  
  return result;
}
function isEmpty(line) {
  return /^\s*$/.test(line);
}

function parseJS(data) {

        let parsed = [];
  
        function rec(bk, o) {
          for (let key of Object.keys(o)) {
            let k = bk ? bk + '.' + key : key;
            if (typeof o[key] === 'object') {
              rec(k, o[key]);
      } else {
              parsed.push([k, o[key]]);
      }
    }
  }

  let jParse = null;
  try {
          jParse = JSON.parse(data.trim());
  } catch (ex) {
          jParse = (new Function('return ' + data.trim()))();
  }
  rec('', jParse);

        return parsed;
}

function toIOS(lines) {
  let out = '';
  for (let line of lines) {
                if (typeof line === 'string') {
            if (line === '') {
              out += '\n';
                                continue;
      }
        
      if (/\n/.test(line))
              out += '/* ' + line + ' */';
      else
              out += '// ' + line;
    } else {
      let key = line[0];
      let value = line[1].replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t').replace(/"/g, '\\"');
      out += `"${key}" = "${value}";`;
    }
    out += '\n';
  }
  
  return out;
}

function toAndroid(lines) {
  let out = '';
  
  for (let line of lines) {
                if (typeof line === 'string') {
            if (line === '') {
              out += '\n';
                                continue;
      }
        
      out += '<!-- ' + line + ' -->';
    } else {
            let key = line[0].replace(/[ \/\\-]/g, '_');
      let value = line[1].replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t');
      out += `<string name="${key}">${value}</string>`;
    }
    out += '\n';
  }
  
  return out;
}

function toJS(lines) {
  let out = {};
  let keyStruct = [];
  let commentI = 0;
  
        let lastKey = '';
  let postponedComments = [];
  
  function outputComments() {
    for (let comment of postponedComments) {
                        let o = out;
      
      for (let k of lastKey ? lastKey.split('.') : []) {
        if (!o.hasOwnProperty(k)) {
          o[k] = {};
        }
        o = o[k];
      }
      
      if (comment === '')
               o['$$empty$$' + commentI++] = comment;
            else o['$$comment$$' + commentI++] = comment;
    }
    postponedComments.length = 0;
  }
  
  for (let line of lines) {
    
                if (typeof line === 'string') {
            postponedComments.push(line);
      continue;
    }
    
    let o = out;
    let key = line[0].split('.');
    let keyBase = key.slice(0, key.length - 1);
    let value = line[1];
    
    if (keyBase !== lastKey) {
            outputComments();
    }
    
    lastKey = keyBase.join('.');
    
    for (let k of key.slice(0, key.length - 1)) {
            if (!o.hasOwnProperty(k)) {
              o[k] = {};
      }
      o = o[k];
    }
    
    o[key[key.length - 1]] = value;
  }
  
  outputComments();
      
  return JSON.stringify(out, false, 2).replace(/"\$\$(comment|empty)\$\$\d+": (".*?"),?\n/g, (m, type, comment) => {
          if (type === 'empty')
      return '\n';
      
          comment = JSON.parse(comment);
    if (/\n/.test(comment))
            return '/* ' + comment + ' */\n';
    return '// ' + comment + '\n';
  });
}

function merge(base, addendum){
  var out = [].concat(base).filter(value => {
    return value != null;
  });
  for(let i in addendum){
    add = true;
    for (let j in base) {
      if (base[j][0] != undefined &&
        addendum[i][0] != undefined &&
        base[j][0] === addendum[i][0]) {
        add = false;
        break;
      }
    }
    if (add) {
      out.push(addendum[i]);
    } else {
      console.warn(addendum[i] + " is already included. Consider removing it from the additional string source!");
    }
  }
  return out;
}

function mergePlurals(base, appendum) {
  for (keyValuePair of appendum) {
    let key = keyValuePair[0];
    if (base[key] === undefined) {
      base.set(key, keyValuePair[1]);
    }
  }
  return base;
}

function parseXMLAndAppend(allElements, stringsXML) {
  var text = fs.readFileSync(stringsXML, 'utf-8').toString();
  let result = parseAndroid(text)
  allElements.parsed = merge(allElements.parsed, result.parsed);
  allElements.parsedPlurals = mergePlurals(allElements.parsedPlurals, result.parsedPlurals);
  return allElements;
}

function convertAndroidToIOS(stringsXMLArray, appleStrings) {
  let allElements = {
    parsed: [],
    parsedPlurals: new Map()
  };

  for (entry of stringsXMLArray) {
    allElements = parseXMLAndAppend(allElements, entry)
    console.log("parsed " + allElements.parsed.length + " elements of " + entry)
  }

  console.log(allElements.parsedPlurals)

  let iosFormatted = toIOS(allElements.parsed);
  fs.writeFile(output, iosFormatted, function (err) {
    if (err) {
      console.error("Error converting " + stringsXMLArray + " to " + appleStrings);
      throw err;
    }
  });
}

if (process.argv.length < 4) {
    console.error('Too less arguments provided. \nExample:\n ' + 
    "node convertTranslations.js stringsInputfile1.xml stringsInputfile2.xml stringsInputfileN.xml stringsOutputfile.strings");
    process.exit(1);
}


var input = process.argv.slice(2, process.argv.length - 1)
var output = process.argv[process.argv.length - 1];
convertAndroidToIOS(input, output)
