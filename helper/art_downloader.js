/*
Art Downloader form the PSBBN Definitive Project
Copyright (C) 2024-2026 CosmicScale

<https://github.com/CosmicScale/PSBBN-Definitive-Project>

SPDX-License-Identifier: GPL-3.0-or-later

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

const fs = require('fs');
const https = require('https');
const readline = require('readline');
const path = require('path');
const { execSync } = require('child_process');

// Check if Puppeteer is installed, and install it if not
try {
    require.resolve('puppeteer');
} catch (e) {
    console.log("Puppeteer not found. Installing...");
    try {
        execSync('npm install puppeteer', { stdio: 'inherit' });
        console.log("Puppeteer installed successfully.");
    } catch (installError) {
        console.error("Failed to install Puppeteer. Ensure you have npm installed and try again.");
        process.exit(1);
    }
}

const puppeteer = require('puppeteer'); // Import Puppeteer after ensuring it's installed

(async () => {
    // Get the game ID from the command-line arguments
    const gameId = process.argv[2];

    if (!gameId) {
        console.error("Usage: node script.js <gameid>");
        process.exit(1); // Exit if no game ID is provided
    }

    const csvFilePath = './helper/ArtDB.csv';
    const outputDir = './icons/art/tmp';

    // Ensure the output directory exists
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    // Function to search the CSV file for the game ID
    const findUrlForGameId = async (gameId) => {
        const fileStream = fs.createReadStream(csvFilePath);
        const rl = readline.createInterface({
            input: fileStream,
            crlfDelay: Infinity,
        });

        for await (const line of rl) {
            const [id, urlPart] = line.split('|');
            if (id === gameId) {
                return `https://www.ign.com/games/${urlPart}`; // Construct the full URL
            }
        }

        return null; // Return null if no match is found
    };

    const url = await findUrlForGameId(gameId);

    if (!url) {
        console.error(`Game ID "${gameId}" not found in ArtDB.csv`);
        process.exit(1);
    }

    const browser = await puppeteer.launch();
    const page = await browser.newPage();

    try {
        console.log(`Navigating to: ${url}`);
        await page.goto(url, { waitUntil: 'networkidle2' });

        // Find the first valid image with src starting with 'https://assets-prd.ignimgs.com'
        let imgUrl = await page.evaluate(() => {
            const imgs = Array.from(document.querySelectorAll('img[src^="https://assets-prd.ignimgs.com"]'));
            const ignored = [
                'https://assets-prd.ignimgs.com/2025/04/03/switch2-doodle-1743697401557.png',
                'https://assets-prd.ignimgs.com/avatars/4ec71177e4b0ca04b5aab1c8/Nix_-_IGN_-_202x-1691124964030.png'
            ];
            for (const img of imgs) {
                const cleanSrc = img.src.split('?')[0]; // Remove query parameters
                if (!ignored.includes(cleanSrc)) {
                    return cleanSrc;
                }
            }
            return null;
        });

        // Fallback to 'https://media.ign.com' if no image is found
        if (!imgUrl) {
            console.log("No image found on assets-prd.ignimgs.com. Checking media.ign.com...");

            imgUrl = await page.evaluate(() => {
                const img = document.querySelector('img[src^="https://media.ign.com"]');
    
                if (img) {
                    return img.src.split('?')[0]; // Remove query parameters
                }
                return null;
            });
        }

        // Fallback to 'https://ps2media.ign.com' if no image is found
        if (!imgUrl) {
            console.log("No image found on media.ign.com. Checking ps2media.ign.com...");

            imgUrl = await page.evaluate(() => {
                const img = document.querySelector('img[src^="https://ps2media.ign.com"]');
    
                if (img) {
                    return img.src.split('?')[0]; // Remove query parameters
                }
                return null;
            });
        }

        // Fallback to 'https://ps3media.ign.com' if no image is found
        if (!imgUrl) {
            console.log("No image found on ps2media.ign.com. Checking ps3media.ign.com...");

            imgUrl = await page.evaluate(() => {
                const img = document.querySelector('img[src^="https://ps3media.ign.com"]');
    
                if (img) {
                    return img.src.split('?')[0]; // Remove query parameters
                }
                return null;
            });
        }

        // Fallback to 'https://media.gamestats.com' if no image is found
        if (!imgUrl) {
            console.log("No image found on ps3media.ign.com. Checking media.gamestats.com...");

            imgUrl = await page.evaluate(() => {
                const img = document.querySelector('img[src^="https://media.gamestats.com"]');

                if (img) {
                    return img.src.split('?')[0]; // Remove query parameters
                }
                return null;
            });
        }

        // Fallback to 'https://assets1.ignimgs.com' if no image is found
        if (!imgUrl) {
            console.log("No image found on media.gamestats.com. Checking assets1.ignimgs.com...");

            imgUrl = await page.evaluate(() => {
                const img = document.querySelector('img[src^="https://assets1.ignimgs.com"]');
    
                if (img) {
                    return img.src.split('?')[0]; // Remove query parameters
                }
                return null;
            });
        }

        if (imgUrl) {
            // Get the file extension from the URL
            const fileExtension = path.extname(imgUrl).split('?')[0]; // Ensures query strings don't interfere
            const fileName = path.join(outputDir, `${gameId}${fileExtension}`);

            console.log(`Downloading image from: ${imgUrl}`);

            // Use https.get for all image downloads
            const downloadImage = (url, destination) => {
                return new Promise((resolve, reject) => {
                    const file = fs.createWriteStream(destination);
                    const options = {
                        headers: {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
                        }
                    };

                    https.get(url, options, (response) => {
                        if (response.statusCode !== 200) {
                            reject(new Error(`Failed to download image: ${response.statusCode}`));
                            return;
                        }
                        response.pipe(file);
                        file.on('finish', () => file.close(resolve));
                    }).on('error', (err) => {
                        fs.unlink(destination, () => reject(err)); // Delete incomplete file
                    });
                });
            };

            try {
                await downloadImage(imgUrl, fileName);
                console.log(`Saved as: ${fileName}`);
            } catch (downloadError) {
                console.error(`Error downloading image: ${downloadError.message}`);
            }
        } else {
            console.log("No image found on either source.");
        }
    } catch (error) {
        console.error(`Failed to fetch the page: ${error.message}`);
    }

    await browser.close();
})();
