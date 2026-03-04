pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    property int refCount: 0
    property string activeInterface: ""
    property string routeInterface: ""
    property real rxSpeed: 0
    property real txSpeed: 0
    property string rxText: "0B/s"
    property string txText: "0B/s"

    property real lastRxBytes: 0
    property real lastTxBytes: 0
    property real lastTimestamp: 0
    property int refreshCounter: 0

    // 5-second rolling average
    property var rxHistory: []
    property var txHistory: []
    property int historySize: 5

    function resetStats(): void {
        root.lastRxBytes = 0;
        root.lastTxBytes = 0;
        root.lastTimestamp = 0;
        root.rxSpeed = 0;
        root.txSpeed = 0;
        root.rxText = "0B/s";
        root.txText = "0B/s";
        root.rxHistory = [];
        root.txHistory = [];
    }

    function addSample(history, sample) {
        history.push(sample);
        if (history.length > historySize)
            history.shift();
        return history;
    }

    function calcAverage(history) {
        if (history.length === 0) return 0;
        let sum = 0;
        for (const v of history) sum += v;
        return sum / history.length;
    }

    function formatSpeed(bytesPerSec: real): string {
        const kib = 1024;
        const mib = kib * 1024;
        const gib = mib * 1024;

        if (bytesPerSec >= gib)
            return `${(bytesPerSec / gib).toFixed(1)}GiB/s`;
        if (bytesPerSec >= mib)
            return `${(bytesPerSec / mib).toFixed(1)}MiB/s`;
        if (bytesPerSec >= kib)
            return `${Math.round(bytesPerSec / kib)}KiB/s`;
        return `${Math.round(bytesPerSec)}B/s`;
    }

    function parseNetDev(data: string, iface: string): var {
        if (!data || !iface)
            return null;

        const lines = data.trim().split("\n");
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith("Inter-") || trimmed.startsWith("face"))
                continue;
            if (!trimmed.startsWith(`${iface}:`))
                continue;

            const parts = trimmed.split(":");
            if (parts.length < 2)
                return null;

            const values = parts[1].trim().split(/\s+/);
            if (values.length < 9)
                return null;

            return {
                rxBytes: parseInt(values[0], 10) || 0,
                txBytes: parseInt(values[8], 10) || 0
            };
        }

        return null;
    }

    function updateInterface(): void {
        let iface = "";

        if (root.routeInterface) {
            iface = root.routeInterface;
        } else if (Nmcli.activeEthernet && Nmcli.activeEthernet.interface) {
            iface = Nmcli.activeEthernet.interface;
        } else {
            if (Nmcli.wirelessInterfaces.length === 0) {
                Nmcli.getWirelessInterfaces(() => {});
            }

            const activeWireless = Nmcli.wirelessInterfaces.find(iface => Nmcli.isConnectedState(iface.state));
            if (activeWireless && activeWireless.device) {
                iface = activeWireless.device;
            } else if (Nmcli.activeInterface) {
                iface = Nmcli.activeInterface;
            }
        }

        if (iface !== root.activeInterface) {
            root.activeInterface = iface;
            resetStats();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.refCount > 0
        triggeredOnStart: true
        onTriggered: {
            refreshCounter = (refreshCounter + 1) % 5;
            if (refreshCounter === 0 && Nmcli.wirelessInterfaces.length === 0) {
                Nmcli.getWirelessInterfaces(() => {});
            }
            routeView.reload();
        }
    }

    FileView {
        id: routeView

        path: "/proc/net/route"
        onLoaded: {
            let iface = "";
            const lines = text().trim().split("\n");
            for (let i = 1; i < lines.length; i++) {
                const cols = lines[i].trim().split(/\s+/);
                if (cols.length < 2)
                    continue;
                if (cols[1] === "00000000") {
                    iface = cols[0];
                    break;
                }
            }

            if (iface !== root.routeInterface) {
                root.routeInterface = iface;
            }
            updateInterface();
            netDev.reload();
        }
    }

    FileView {
        id: netDev

        path: "/proc/net/dev"
        onLoaded: {
            const stats = parseNetDev(text(), root.activeInterface);
            if (!stats) {
                root.rxSpeed = 0;
                root.txSpeed = 0;
                root.rxText = "0B/s";
                root.txText = "0B/s";
                return;
            }

            const now = Date.now();
            if (root.lastTimestamp > 0) {
                const elapsed = (now - root.lastTimestamp) / 1000;
                if (elapsed > 0) {
                    const rxDelta = stats.rxBytes - root.lastRxBytes;
                    const txDelta = stats.txBytes - root.lastTxBytes;
                    const instantRx = Math.max(0, rxDelta / elapsed);
                    const instantTx = Math.max(0, txDelta / elapsed);

                    // Add to rolling history
                    root.rxHistory = addSample(root.rxHistory, instantRx);
                    root.txHistory = addSample(root.txHistory, instantTx);

                    // Calculate 5-second average
                    root.rxSpeed = calcAverage(root.rxHistory);
                    root.txSpeed = calcAverage(root.txHistory);
                }
            }

            root.lastRxBytes = stats.rxBytes;
            root.lastTxBytes = stats.txBytes;
            root.lastTimestamp = now;
            root.rxText = formatSpeed(root.rxSpeed);
            root.txText = formatSpeed(root.txSpeed);
        }
    }
}
