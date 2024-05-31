import * as fs from 'fs';


// Function to save object to JSON file with error handling
function saveObjectToFile<T>(filename: string, obj: T): void {
    try {
        const json = JSON.stringify(obj, null, 2); // Convert object to JSON string
        fs.writeFileSync(filename, json, 'utf8');  // Write JSON string to file
        console.log(`Successfully saved data to ${filename}`);
    } catch (err) {
        console.error(`Error writing to file ${filename}:`, err);
    }
}

// Function to load object from JSON file
function loadObjectFromFile<T>(filename: string, defaultObj: T): T {
    try {
        const data = fs.readFileSync(filename, 'utf8'); // Read file content
        if (data) {
            return JSON.parse(data); // Parse JSON string to object
        }
    } catch (err) {
        // File doesn't exist or is empty
        if (err.code !== 'ENOENT') {
            console.error('Error reading file:', err);
        }
    }
    // Return default object if file is empty or doesn't exist
    return defaultObj;
}

// // Save the object to a file
// saveObjectToFile('data.json', myObject);
//
// // Load the object from the file
// const loadedObject = loadObjectFromFile('data.json');
// console.log(loadedObject);

export {loadObjectFromFile, saveObjectToFile};