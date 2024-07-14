
interface Status {
    hardware_rev: number,
    vers_major: number,
    vers_minor: number,
    wifi_status: number,
    ip: string,
    config?: number, // only for TRS-IO++
    color: number,
    ssid: string,
    passwd: string,
    smb_url: string,
    smb_user: string,
    smb_passwd: string,
    time: string,
    smb_err: string,
    posix_err: string,
    has_sd_card: boolean,
    frehd_loaded: string,
    tz: string,
}

interface Rom {
    filename: string,
    size: number,
    createdAt: number, // seconds since epoch
}

interface RomInfo {
    roms: Rom[],
    selected: string[],
}

interface ErrorResponse {
    error: string,
}

const WIFI_STATUS_TO_STRING = new Map<number,string>([
    [1, "Connecting"],
    [2, "Connected"],
    [3, "Not connected"],
    [4, "Not configured"],
]);

const CONFIGURATIONS = [
    "TRS-IO (Model 1)",
    "TRS-IO (Model III)",
    "PocketTRS (Model 1, internal TRS-IO)",
    "Reserved",
    "PocketTRS (Model III, internal TRS-IO)",
    "PocketTRS (Model 4, internal TRS-IO)",
    "PocketTRS (Model 4P, internal TRS-IO)",
    "Custom 1",
    "Custom 2",
    "PocketTRS (Model 1, external TRS-IO)",
    "Reserved",
    "PocketTRS (Model III, external TRS-IO)",
    "PocketTRS (Model 4, external TRS-IO)",
    "PocketTRS (Model 4P, external TRS-IO)",
    "Custom 1",
    "Custom 2"
];

let g_mostRecentStatus: Status | undefined = undefined;

function updateStatusField(id: string, value: number | string): void {
    if (typeof(value) === "number") {
        value = value.toString();
    }

    const element = document.getElementById(id);
    if (element === null) {
        console.error("Element not found: " + id);
        return;
    }

    element.textContent = value;
}

function getSettingsField(id: string): string {
    const element = document.getElementById(id) as HTMLInputElement;
    if (element === null) {
        console.error("Element not found: " + id);
        return "";
    }

    return element.value;
}

function getSettingsEnumField(name: string): string {
    const elements = document.getElementsByName(name);
    for (const element of elements) {
        const inputElement = element as HTMLInputElement;
        if (inputElement.checked) {
            return inputElement.value;
        }
    }

    return "unknown";
}

function updateSettingsField(id: string, value: string): void {
    const element = document.getElementById(id) as HTMLInputElement;
    if (element === null) {
        console.error("Element not found: " + id);
        return;
    }

    element.value = value;
}

function updateSettingsEnumField(name: string, value: string): void {
    const elements = document.getElementsByName(name);
    for (const element of elements) {
        const inputElement = element as HTMLInputElement;
        inputElement.checked = inputElement.value === value;
    }
}

function updateSettingsForm(status: Status): void {
    updateSettingsEnumField("color", status.color.toString());
    updateSettingsField("tz", status.tz);
    updateSettingsField("ssid", status.ssid);
    updateSettingsField("passwd", status.passwd);
    updateSettingsField("smb_url", status.smb_url);
    updateSettingsField("smb_user", status.smb_user);
    updateSettingsField("smb_passwd", status.smb_passwd);
}

function updateStatus(status: Status, initialFetch: boolean): void {
    g_mostRecentStatus = status;

    updateStatusField("hardware_rev", status.hardware_rev);
    updateStatusField("vers_major", status.vers_major);
    updateStatusField("vers_minor", status.vers_minor);
    updateStatusField("time", status.time);
    updateStatusField("ip", status.ip);
    updateStatusField("wifi_status", WIFI_STATUS_TO_STRING.get(status.wifi_status) ?? "Unknown");
    updateStatusField("smb_err", status.smb_err);
    updateStatusField("posix_err", status.posix_err);
    updateStatusField("frehd_loaded", status.frehd_loaded);

    if (initialFetch) {
        updateSettingsForm(status);
    }
}

async function fetchStatus(initialFetch: boolean) {
    const response = await fetch("/status");
    if (response.status === 200) {
        const status = await response.json() as Status;
        updateStatus(status, initialFetch);
    } else {
        console.log("Error fetching status", response);
    }
}

function scheduleFetchStatus() {
    setInterval(async () => await fetchStatus(false), 2000);
}

function displayError(message: string): void {
    console.log(message); // TODO
}

// Returns whether successful
async function deleteRomFile(filename: string): Promise<boolean> {
    const response = await fetch("/get-roms", {
        method: "POST",
        cache: "no-cache",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            command: "deleteRom",
            filename,
        }),
    });
    if (response.status === 200) {
        const romInfo = await response.json() as RomInfo | ErrorResponse;
        if ("error" in romInfo) {
            displayError(romInfo.error);
        } else {
            updateRomInfo(romInfo);
            return true;
        }
    } else {
        displayError("Error deleting ROM");
    }
    return false;
}

// Returns whether successful
async function renameRomFile(oldFilename: string, newFilename: string): Promise<boolean> {
    const response = await fetch("/get-roms", {
        method: "POST",
        cache: "no-cache",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            command: "renameRom",
            oldFilename,
            newFilename,
        }),
    });
    if (response.status === 200) {
        const romInfo = await response.json() as RomInfo | ErrorResponse;
        if ("error" in romInfo) {
            displayError(romInfo.error);
        } else {
            updateRomInfo(romInfo);
            return true;
        }
    } else {
        displayError("Error renaming ROM");
    }
    return false;
}

function updateRomInfo(romInfo: RomInfo) {
    romInfo.roms.sort((a, b) => {
        return a.filename.localeCompare(b.filename, undefined, {
            numeric: true,
        });
    });

    const tbody = document.querySelector(".rom-table tbody") as HTMLElement;
    tbody.replaceChildren();

    for (let romIndex = 0; romIndex < romInfo.roms.length; romIndex++) {
        const rom = romInfo.roms[romIndex];

        const tr = document.createElement("tr");
        let td;

        let filenameTd = document.createElement("td");
        filenameTd.textContent = rom.filename;
        tr.append(filenameTd);

        td = document.createElement("td");
        const renameIcon = document.createElement("img");
        renameIcon.src = "/icons/edit.svg";
        const renameLink = document.createElement("a");
        renameLink.append(renameIcon);
        renameLink.href = "#";
        renameLink.addEventListener("click", async e => {
            e.preventDefault();
            startRename();
        });
        td.append(renameLink);
        tr.append(td);

        td = document.createElement("td");
        td.textContent = rom.size.toLocaleString(undefined, {
            useGrouping: true,
        });
        tr.append(td);

        td = document.createElement("td");
        td.textContent = new Date(rom.createdAt*1000).toLocaleString(undefined, {
            dateStyle: "short",
        } as any); // "any" needed because TS doesn't know about "dateStyle" option.
        tr.append(td);

        const startRename = () => {
            if (tbody.classList.contains("renaming")) {
                return;
            }
            tbody.classList.add("renaming");

            filenameTd.contentEditable = "true";
            filenameTd.focus();

            // Select entire filename.
            const textNode = filenameTd.childNodes[0];
            if (textNode.textContent !== null) {
                const filename = textNode.textContent;
                const dot = filename.lastIndexOf(".");
                const range = document.createRange();
                range.setStart(textNode, 0);
                range.setEnd(textNode, dot === -1 ? textNode.textContent.length : dot);

                const s = window.getSelection();
                if (s !== null) {
                    s.removeAllRanges();
                    s.addRange(range)
                }
            }

            const finish = () => {
                filenameTd.removeEventListener("blur", blurListener);
                filenameTd.removeEventListener("keydown", keyListener);
                filenameTd.contentEditable = "false";
                window.getSelection()?.removeAllRanges();
                tbody.classList.remove("renaming");
            };

            const rollback = () => {
                // Abort and return to old name.
                filenameTd.textContent = rom.filename;
                finish();
            };

            const commit = async () => {
                const newFilename = filenameTd.textContent;
                if (newFilename === null || newFilename === "" || newFilename === rom.filename) {
                    rollback();
                } else {
                    const success = await renameRomFile(rom.filename, newFilename);
                    if (success) {
                        finish();
                    } else {
                        rollback();
                    }
                }
            };

            const blurListener = () => {
                commit();
            };

            const keyListener = (e: KeyboardEvent) => {
                switch (e.key) {
                    case "Enter":
                        e.preventDefault();
                        commit();
                        break;

                    case "Escape":
                        e.preventDefault();
                        rollback();
                        break;
                }
            };

            filenameTd.addEventListener("blur", blurListener);
            filenameTd.addEventListener("keydown", keyListener);
        };
        filenameTd.addEventListener("click", () => startRename());

        for (let model of [0, 2, 3, 4]) {
            td = document.createElement("td");
            const input = document.createElement("input");
            input.type = "radio";
            input.name = "modelRom" + model;
            if (romInfo.selected[model] === rom.filename) {
                input.checked = true;
            }
            td.append(input);
            tr.append(td);
        }

        td = document.createElement("td");
        const deleteIcon = document.createElement("img");
        deleteIcon.src = "/icons/delete.svg";
        const deleteLink = document.createElement("a");
        deleteLink.append(deleteIcon);
        deleteLink.href = "#";
        deleteLink.addEventListener("click", async e => {
            e.preventDefault();
            const success = await deleteRomFile(rom.filename);
        });
        td.append(deleteLink);
        tr.append(td);

        tbody.append(tr);
    }
}

async function fetchRomInfo() {
    const response = await fetch("/get-roms");
    if (response.status === 200) {
        const romInfo = await response.json() as RomInfo;
        updateRomInfo(romInfo);
    } else {
        console.log("Error fetching ROM info", response);
    }
}

async function sleep(ms: number): Promise<void> {
    return new Promise<void>(accept => {
        setTimeout(() => accept(), ms);
    });
}

async function startSaveIndicator(): Promise<void> {
    const stars = document.createElement("span");
    stars.classList.add("stars");

    const container = document.querySelector(".article-container") as Element;
    container.append(stars);

    for (let i = 0; i < 5; i++) {
        stars.textContent = "*" + (i % 2 === 0 ? "*" : "\u00A0"); // nbsp
        await sleep(200);
    }

    stars.remove();
}

async function saveSettings(): Promise<void> {
    const settings = {
        color: parseInt(getSettingsEnumField("color")),
        tz: getSettingsField("tz"),
        ssid: getSettingsField("ssid"),
        passwd: getSettingsField("passwd"),
        smb_url: getSettingsField("smb_url"),
        smb_user: getSettingsField("smb_user"),
        smb_passwd: getSettingsField("smb_passwd"),
    };

    const responsePromise = fetch("/config", {
        method: "POST",
        cache: "no-cache",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify(settings),
    });
    const saveIndicatorPromise = startSaveIndicator();
    const [response, _] = await Promise.all([responsePromise, saveIndicatorPromise]);
    if (response.status !== 200) {
        console.log("Failed to save settings", response);
    } else {
        const status = await response.json() as Status;
        updateStatus(status, false);
    }
}

function resizeDots(): void {
    const canvas = document.getElementById("dots_canvas") as HTMLCanvasElement;
    const parent = canvas.parentNode as HTMLElement;

    canvas.width = parent.offsetWidth;
    canvas.height = parent.offsetHeight;
}

function redrawDots(): void {
    const canvas = document.getElementById("dots_canvas") as HTMLCanvasElement;
    const ctx = canvas.getContext("2d") as CanvasRenderingContext2D;

    ctx.fillStyle = "rgb(0 0 0 / 0%)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const width = canvas.width;
    const height = canvas.height;
    const emptyY = height*3/6;
    const fullY = height*5/6;

    ctx.fillStyle = "#67525440"; // var(--brown)
    for (let y = 0; y < height; y++) {
        const t = Math.min(Math.max((y - emptyY) / (fullY - emptyY), 0), 1);
        const dotCount = t*30;

        for (let c = 0; c < dotCount; c++) {
            ctx.beginPath();
            ctx.arc(Math.random()*width, y, 1.2, 0, 2*Math.PI);
            ctx.fill();
        }
    }
}

function configureButtons() {
    const timezoneDetectButton = document.getElementById("timezoneDetectButton");
    const timezoneField = document.getElementById("tz") as HTMLInputElement | null;
    if (timezoneDetectButton !== null && timezoneField !== null) {
        timezoneDetectButton.addEventListener("click", () => {
            const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
            if (timezone !== "") {
                timezoneField.value = timezone;
            }
        });
    }

    const saveStatusButton = document.getElementById("saveSettings") as HTMLButtonElement;
    saveStatusButton.addEventListener("click", () => saveSettings());

    const revertStatusButton = document.getElementById("revertSettings") as HTMLButtonElement;
    revertStatusButton.addEventListener("click", () => {
        if (g_mostRecentStatus !== undefined) {
            updateSettingsForm(g_mostRecentStatus);
        }
    });
}

async function handleRomUpload(file: File) {
    const contents = new Uint8Array(await file.arrayBuffer());
    const contentsString = Array.from(contents, byte => String.fromCodePoint(byte)).join("");

    const response = await fetch("/get-roms", {
        method: "POST",
        cache: "no-cache",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            command: "uploadRom",
            filename: file.name,
            contents: window.btoa(contentsString),
        }),
    });
    if (response.status !== 200) {
        displayError("Error uploading ROM");
    } else {
        const romInfo = await response.json() as RomInfo | ErrorResponse;
        if ("error" in romInfo) {
            displayError(romInfo.error);
        } else {
            updateRomInfo(romInfo);
            return true;
        }
    }
}

async function handleRomDrop(e: DragEvent) {
    // Prevent default behavior (Prevent file from being opened)
    e.preventDefault();

    if (e.dataTransfer) {
        if (e.dataTransfer.items) {
            // Use DataTransferItemList interface to access the files.
            for (const item of e.dataTransfer.items) {
                // If dropped items aren't files, reject them
                if (item.kind === "file") {
                    const file = item.getAsFile();
                    if (file) {
                        await handleRomUpload(file);
                    }
                }
            }
        } else {
            // Use DataTransfer interface to access the files.
            for (const file of e.dataTransfer.files) {
                await handleRomUpload(file);
            }
        }
    }
}

function configureRomUpload() {
    const uploadRomInput = document.getElementById("uploadRomInput") as HTMLInputElement;
    uploadRomInput.addEventListener("change", async () => {
        if (uploadRomInput.files !== null) {
            for (const file of uploadRomInput.files) {
                await handleRomUpload(file);
            }
            uploadRomInput.value = "";
        }
    });

    const romsSection = document.querySelector(".roms") as HTMLElement;
    romsSection.addEventListener("drop", async e => {
        romsSection.classList.remove("hover")
        await handleRomDrop(e);
    });
    romsSection.addEventListener("dragover", e => {
        romsSection.classList.add("hover");

        // Prevent default behavior (prevent file from being opened).
        e.preventDefault();
    });
    romsSection.addEventListener("dragleave",  () => romsSection.classList.remove("hover"));
}

export function main() {
    configureButtons();
    configureRomUpload();
    fetchStatus(true);
    fetchRomInfo();
    resizeDots();
    redrawDots();
    scheduleFetchStatus();
}
