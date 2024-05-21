var fs = require('fs');

function parseAndroid(data) {

  const rgxKeyValue = /<string name\s*=\s*"(.*?)".*?>(.*)<\/string>/;
  const rgxCommentBlock = /<!-- ?(.*?) ?-->/;
  const rgxCommentStart = /<!-- ?(.*)/;
  const rgxCommentEnd = /(.*?) ?-->/;
  const rgxPluralsStart = /<plurals name\s*=\s*"(.*)"\s*>/;
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
      value = kv[2].
      replace(/([^\\])(")/g, '$1\\$2').
      replace(/&quot;/g, '\\"').
      replace(/&lt;/g, '<').
      replace(/&gt;/g, '>').
      replace(/&amp;/g, '&').
      replace(/\$s/ig, '$@').
      replace(/\%s/ig, '%1$@')

      let countOfPlaceholders = (value.match(/\%1\$\@/g) || []).length
      if (countOfPlaceholders > 1) {
        console.error("\n\n\n ERROR: Placeholder mismatch. A source file contained '%s' and '%1$s' in the same resource which we are not willing to fix automatically. Please fix the input source on tranisfex first! context:\n" + line +  "\n\n\n")
        continue;
      }

      result.parsed.push([kv[1], value])
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
function toStringsDict(pluralsMap) {
    if (!pluralsMap || pluralsMap.length == 0) {
      return;
    } 

    const rgxZero = /<item quantity="zero">(.*)<\/item>/;
    const rgxOne = /<item quantity="one">(.*)<\/item>/;
    const rgxTwo = /<item quantity="two">(.*)<\/item>/;
    const rgxFew = /<item quantity="few">(.*)<\/item>/;
    const rgxMany = /<item quantity="many">(.*)<\/item>/;
    const rgxOther = /<item quantity="other">(.*)<\/item>/;

    let out = '\<?xml version=\"1.0\" encoding=\"UTF-8\"?\>\n';
    out += '\<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\>\n';
    out += '\<plist version="1.0"\>\n';
    out += '\<dict\>\n';
    for (keyValuePair of pluralsMap) {
        let key = keyValuePair[0];
        out += '\t\<key\>' + key + '\</key\>\n';
        out += '\t\<dict\>\n';
        out += '\t\t\<key\>NSStringLocalizedFormatKey\</key\>\n'
        out += '\t\t\<string\>%#@localized_format_key@\</string\>\n'
        out += '\t\t\<key\>localized_format_key\</key\>\n'
        out += '\t\t\<dict\>\n'
        out += '\t\t\t\<key\>NSStringFormatSpecTypeKey\</key\>\n'
        out += '\t\t\t\<string\>NSStringPluralRuleType\</string\>\n'
        out += '\t\t\t\<key\>NSStringFormatValueTypeKey\</key\>\n'
        out += '\t\t\t\<string\>d\</string\>\n'
        let lines = keyValuePair[1];
        let zero = lines.filter( value => value.match(rgxZero));
        let one = lines.filter( value => value.match(rgxOne));
        let two = lines.filter( value => value.match(rgxTwo));
        let few = lines.filter( value => value.match(rgxFew));
        let many = lines.filter( value => value.match(rgxMany));
        let other = lines.filter( value => value.match(rgxOther))
        if (zero.length > 0) {
          out += '\t\t\t\<key\>zero\</key\>\n';
          out += '\t\t\t\<string\>'+zero[0].match(rgxZero)[1]+'\</string\>\n';
        }
        if (one.length > 0) {
          out += '\t\t\t\<key\>one\</key\>\n';
          out += '\t\t\t\<string\>'+one[0].match(rgxOne)[1]+'\</string\>\n';
        }
        if (two.length > 0) {
          out += '\t\t\t\<key\>two\</key\>\n';
          out += '\t\t\t\<string\>'+two[0].match(rgxTwo)[1]+'\</string\>\n';
        }
        if (few.length > 0) {
          out += '\t\t\t\<key\>few\</key\>\n';
          out += '\t\t\t\<string\>'+few[0].match(rgxFew)[1]+'\</string\>\n';
        }
        if (many.length > 0) {
          out += '\t\t\t\<key\>many\</key\>\n';
          out += '\t\t\t\<string\>'+many[0].match(rgxMany)[1]+'\</string\>\n';
        }
        if (other.length > 0) {
          out += '\t\t\t\<key\>other\</key\>\n';
          out += '\t\t\t\<string\>'+other[0].match(rgxOther)[1]+'\</string\>\n';
        }
        out += '\t\t\</dict\>\n'
        out += '\t\</dict\>\n';
    }
    out += '\</dict\>\n';
    out += '\</plist\>\n';

    return out;
}

function toInfoPlistStrings(lines) {
    let out = '';
    for (let line of lines) {
      if (typeof line === 'string') {
        continue;
      } else {
        let key = line[0];
        if (!key.startsWith("InfoPlist_")) {
          continue;
        }
        key = key.replace('InfoPlist_', '');
        out += `${key} = "${line[1]}";\n`;
      }
    }
    return out;
}

function toLocalizableStrings(lines) {
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
      if (key.startsWith("InfoPlist_")) {
        continue;
      }
      out += `"${key}" = "${line[1]}";`;
    }
    out += '\n';
  }
  return out;
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
    console.log("parsed " + allElements.parsed.length + " for Localizable.strings and " + allElements.parsedPlurals.size + " entries for Localizable.stringsdict" + " after reading " + entry);
  }

  let iosFormatted = toLocalizableStrings(allElements.parsed);
  let iosFormattedInfoPlist = toInfoPlistStrings(allElements.parsed);
  let iosFormattedPlurals = toStringsDict(allElements.parsedPlurals);

  let localizableStrings = output + "/Localizable.strings";
  let infoPlistStrings = output + "/InfoPlist.strings";
  let stringsDict = output + "/Localizable.stringsdict";
  fs.writeFile(localizableStrings, iosFormatted, function (err) {
    if (err) {
      console.error("Error converting " + stringsXMLArray + " to " + localizableStrings);
      throw err;
    }
  });

  fs.writeFile(infoPlistStrings, iosFormattedInfoPlist, function (err) {
    if (err) {
      console.error("Error converting " + stringsXMLArray + " to " + infoPlistStrings);
      throw err;
    }
  });

  fs.writeFile(stringsDict, iosFormattedPlurals, function (err) {
    if (err) {
      console.error("Error converting " + stringsXMLArray + " to " + stringsDict);
      throw err;
    }
  });
}

if (process.argv.length < 4) {
    console.error('Too less arguments provided. \nExample:\n ' + 
    "node convertTranslations.js stringsInputfile1.xml stringsInputfile2.xml stringsInputfileN.xml path/to/outputfolder");
    process.exit(1);
}


var input = process.argv.slice(2, process.argv.length - 1)
var output = process.argv[process.argv.length - 1];
convertAndroidToIOS(input, output)
