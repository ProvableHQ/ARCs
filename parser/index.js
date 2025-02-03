const fs = require('fs');
const glob = require("glob");
const parseMD = require('parse-md').default;

/**
 * arc: 1
 * title: Template
 * authors: The Aleo Team <hello@aleo.org>
 * discussion: 
 * topic: Meta
 * status: Living
 * created: 2020-02-07
 */
const requiredMetadata = ['arc', 'title', 'authors', 'discussion', 'topic', 'status', 'created'];

const topics = ['Protocol', 'Network', 'Application', 'Meta'];

const statuses = ['Draft', 'Active', 'Withdrawn', 'Accepted', 'Final', 'Deprecated', 'Living'];

// Executes sanity checks for CI.
const ci = () => {
    getArcDirectories('..', async (err, list) => {
        if (err) {
            console.log('Error', err);
            process.exit(1);
        } else {
            for (let i = 1; i < list.length; i++) {
                const arcDirectory = list[i];

                /**************************** ****************************/
                /***************** ADD NEW CI CHECKS HERE ****************/
                /**************************** ****************************/

                await checkArcReadmeExists(arcDirectory);
                await checkArcReadmeContent(arcDirectory);

                /**************************** ****************************/
                /**************************** ****************************/
                /**************************** ****************************/

                if (i === list.length - 1) {
                    console.log("\nAll ARCs are up to standard!\n");
                }
            }
        }
    })
}

// Builds pages for site.
const site = () => {
    getArcDirectories('..', async (err, list) => {
        if (err) {
            console.log('Error', err);
            process.exit(1);
        } else {

            let arcs = {};

            for (let i = 1; i < list.length; i++) {
                const arcDirectory = list[i];

                /**************************** ****************************/
                /**************** ADD NEW SITE LOGIC HERE ****************/
                /**************************** ****************************/

                await checkArcReadmeExists(arcDirectory);
                await checkArcReadmeContent(arcDirectory);

                const { id, metadata, content } = parseArcReadme(arcDirectory);
                // Skip adding arc-0000 template.
                if (id !== 0) {
                    arcs[id] = { metadata, content };
                }

                /**************************** ****************************/
                /**************************** ****************************/
                /**************************** ****************************/

                if (i === list.length - 1) {
                    console.log("\nSuccessfully built all ARCs!");

                    // Write the processed ARCs to the `site` directory.
                    const path = "../site/src/arcs.json";
                    fs.writeFileSync(path, JSON.stringify(arcs, null, 4));

                    console.log(`\nSuccessfully wrote all ARCs to ${path}!\n`);
                }
            }
        }
    })
}

/***************************************************** ****************************************************************/
/***************************************************** ****************************************************************/
/***************************************************** ****************************************************************/
/*************************************** HELPER METHODS ONLY BELOW ****************************************************/
/***************************************************** ****************************************************************/
/***************************************************** ****************************************************************/
/***************************************************** ****************************************************************/

// Returns a list of CLI arguments.
const cliArguments = process.argv.slice(2);

// Returns a list of relative paths to every ARC directory.
const getArcDirectories = (relativePathToRoot, callback) => {
    glob(relativePathToRoot + '/arc-*', callback);
};

// Checks that a README.md file exists in a given 'arc-xxxx' directory.
const checkArcReadmeExists = async (arcDirectory) => {
    const arcReadmeFile = arcDirectory + '/README.md';
    try {
        if (!fs.existsSync(arcReadmeFile)) {
            console.error('Could not find', arcReadmeFile);
            process.exit(1);
        }
    } catch(err) {
        console.error('Could not find', arcReadmeFile);
        process.exit(1);
    }
}

// Checks that a README.md file has the required content for a given 'arc-xxxx' directory.
const checkArcReadmeContent = async (arcDirectory) => {
    const arcReadmeFile = arcDirectory + '/README.md';
    const fileContents = fs.readFileSync(arcReadmeFile, 'utf8');
    const { metadata, content } = parseMD(fileContents);

    /**
     * arc: 1
     * title: Template
     * authors: The Aleo Team <hello@aleo.org>
     * discussion: 
     * topic: Meta
     * status: Living
     * created: 2020-02-07
     */

    // Check that the metadata is fully filled in.
    for (let i = 0; i < requiredMetadata.length; i++) {
        const metatopic = requiredMetadata[i];
        if (!metadata.hasOwnProperty(metatopic)) {
            console.error('\n', arcReadmeFile, 'is missing \'', metatopic, '\'.\n');
            process.exit(1);
        }

        // Check that the ARC # matches the directory #.
        if (metatopic === 'arc') {
            try {
                const directoryNumber = parseInt(arcDirectory.split('-')[1]);
                const metadataNumber = parseInt(metadata.arc);
                if (directoryNumber !== metadataNumber) {
                    console.error('\nARC directory ID (', arcDirectory, ') does not match the ARC ID in the README (', metadataNumber, ').\n');
                    process.exit(1);
                }
            } catch (err) {
                console.error("\nFailed to check that", arcDirectory, "has a matching ARC number.\n");
                process.exit(1)
            }
        }

        // Check that the ARC title is nonempty.
        if (metatopic === 'title') {
            const title = metadata['title'];
            if (title === null || title === undefined || title === "") {
                console.error('\nARC title cannot be empty.\n');
                process.exit(1);
            }
        }

        // Check that the ARC authors is nonempty.
        if (metatopic === 'authors') {
            const authors = metadata['authors'];
            if (authors === null || authors === undefined || authors === "") {
                console.error('\nARC authors cannot be empty.\n');
                process.exit(1);
            }
        }

        // Check that the ARC topic matches a valid topic.
        if (metatopic === 'topic') {
            if (!topics.includes(metadata['topic'])) {
                console.error('\nARC topic (', metadata['topic'], ') is not an accepted topic.\n');
                process.exit(1);
            }
        }

        // Check that the ARC status matches a valid status.
        if (metatopic === 'status') {
            if (!statuses.includes(metadata['status'])) {
                console.error('\nARC status (', metadata['status'], ') is not an accepted status.\n');
                process.exit(1);
            }
        }

        // Check that the ARC created is nonempty.
        if (metatopic === 'created') {
            const created = metadata['created'];
            if (created === null || created === undefined || created === "") {
                console.error('\nARC created cannot be empty.\n');
                process.exit(1);
            }
        }
    }

    // Check that the main body is not empty.
    if (content === null || content === undefined || content === "") {
        console.error('\n', arcReadmeFile, 'is empty.\n');
        process.exit(1);
    }
}

// Returns the metadata and content of the README file for a given ARC.
const parseArcReadme = (arcDirectory) => {
    const arcReadmeFile = arcDirectory + '/README.md';
    const fileContents = fs.readFileSync(arcReadmeFile, 'utf8');
    const { metadata, content } = parseMD(fileContents);
    const id = metadata.arc;
    return { id, metadata, content }
}

// The main program.
const main = () => {
    if (cliArguments.length === 0) {
        console.error('\nPlease provide one CLI argument: \'ci\', \'site\'\n');
    } else {
        switch (cliArguments[0].toLowerCase()) {
            case 'ci':
                ci();
                break;
            case 'site':
                site();
                break;
            default:
                console.error('\nInvalid command. Please provide a valid CLI argument: \'ci\', \'site\'\n');
        }
    }
}

main()
