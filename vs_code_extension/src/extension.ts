import * as vscode from 'vscode';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {

	const debugAdapterDescriptorFactory = new DartDebugAdapterDescriptorFactory(context);
	context.subscriptions.push(vscode.debug.registerDebugAdapterDescriptorFactory("dart-custom", debugAdapterDescriptorFactory));
}

export class DartDebugAdapterDescriptorFactory implements vscode.DebugAdapterDescriptorFactory {
	constructor(private readonly extensionContext: vscode.ExtensionContext) { }
	public createDebugAdapterDescriptor(session: vscode.DebugSession, executable: vscode.DebugAdapterExecutable | undefined): vscode.ProviderResult<vscode.DebugAdapterDescriptor> {
		const portEnv = process.env['CUSTOM_DAP_SERVER_PORT'];
		const port = portEnv ? parseInt(portEnv, 10) : undefined;
		if (port) {
			return new vscode.DebugAdapterServer(port);
		} else {
			// TODO: This is for local testing and runs the adapter from source in non-server mode.
			// To ship, the adapter should be compiled and included in the extension, and the binary
			// path used here instead.
			const adapterFile = path.join(this.extensionContext.extensionPath, "../custom_adapter/bin/custom_adapter.dart");
			// "dart" should really be a full absolute path to an SDK in case dart is not on PATH.
			return new vscode.DebugAdapterExecutable("dart", [adapterFile]);
		}
	}
}
