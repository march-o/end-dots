.pragma library

// Numbered workspaces are row-major; hidden workspaces form one adjacent column.
function move(index, direction, hiddenCount, rows, columns) {
    const count = rows * columns;
    const total = count + hiddenCount;
    index = Math.max(0, Math.min(total - 1, index));
    if (direction === "next") return (index + 1) % total;
    if (direction === "previous") return (index + total - 1) % total;
    if (index >= count) {
        const hidden = index - count;
        if (direction === "up") return count + (hidden + hiddenCount - 1) % hiddenCount;
        if (direction === "down") return count + (hidden + 1) % hiddenCount;
        if (direction === "left") return Math.round(hidden / Math.max(1, hiddenCount - 1) * (rows - 1)) * columns + columns - 1;
        return index;
    }
    const row = Math.floor(index / columns);
    const column = index % columns;
    if (direction === "up") return ((row + rows - 1) % rows) * columns + column;
    if (direction === "down") return ((row + 1) % rows) * columns + column;
    if (direction === "left") return Math.max(row * columns, index - 1);
    if (direction === "right") {
        if (column < columns - 1) return index + 1;
        if (hiddenCount) return count + Math.round(row / Math.max(1, rows - 1) * (hiddenCount - 1));
    }
    return index;
}

function displayName(name) {
    const clean = String(name).replace(/^special:/, "");
    if (clean === "special") return "Scratchpad";
    return clean.replace(/[-_]+/g, " ").replace(/\b\w/g, letter => letter.toUpperCase());
}
