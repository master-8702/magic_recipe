import 'package:magic_recipe_client/magic_recipe_client.dart';
import 'package:flutter/material.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Sets up a global client object that can be used to talk to the server from
/// anywhere in our app. The client is generated from your server code
/// and is set up to connect to a Serverpod running on a local server on
/// the default port. You will need to modify this to connect to staging or
/// production servers.
/// In a larger app, you may want to use the dependency injection of your choice instead of
/// using a global client object. This is just a simple example.
late final Client client;

late String serverUrl;

void main() {
  // When you are running the app on a physical device, you need to set the
  // server URL to the IP address of your computer. You can find the IP
  // address by running `ipconfig` on Windows or `ifconfig` on Mac/Linux.
  // You can set the variable when running or building your app like this:
  // E.g. `flutter run --dart-define=SERVER_URL=https://api.example.com/`
  const serverUrlFromEnv = String.fromEnvironment('SERVER_URL');
  final serverUrl =
      serverUrlFromEnv.isEmpty ? 'http://$localhost:8080/' : serverUrlFromEnv;

  client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'magic recipe generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Magic Recipe Generator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  /// Holds the last result or null if no result exists yet.
  Recipe? _recipe;

  List<Recipe> _recipeHistory = [];

  /// Holds the last error message that we've received from the server or null if no
  /// error exists yet.
  String? _errorMessage;

  final _textEditingController = TextEditingController();

  bool _isLoading = false;

  void _callGenerateRecipe() async {
    try {
      setState(() {
        // Reset the result and error messages and set loading state.
        _errorMessage = null;
        _recipe = null;
        _isLoading = true;
      });

      final recipe =
          await client.recipes.generateRecipe(_textEditingController.text);

      setState(() {
        // Set the result message and reset the error message.
        _errorMessage = null;
        _recipe = recipe;
        _isLoading = false;
        // Add to history
        _recipeHistory.insert(0, recipe);
      });
    } catch (e) {
      setState(() {
        // If an error occurs, set the error message and reset the result message.
        _errorMessage = e.toString();
        _recipe = null;
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch the recipe history from the database when the widget is created.
    client.recipes.getRecipes().then(
      (myRecipes) {
        setState(() {
          _recipeHistory = myRecipes;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(children: [
                    Text('Recipe History',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Expanded(
                      child: ListView.builder(
                          itemCount: _recipeHistory.length,
                          itemBuilder: (context, index) {
                            final recipe = _recipeHistory[index];
                            return ListTile(
                              onTap: () {
                                _textEditingController.text =
                                    recipe.ingredients;
                                setState(() {
                                  _recipe = recipe;
                                });
                              },
                              title: Text(recipe.text.split('\n').first),
                              subtitle:
                                  Text('${recipe.author} on ${recipe.date}'),
                            );
                          }),
                    )
                  ]),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TextField(
                      controller: _textEditingController,
                      decoration: const InputDecoration(
                        hintText:
                            'Enter ingredients (e.g. "chicken, rice, broccoli")',
                        // label: Text('Ingredients'),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton(
                      // prevent the user from calling the method again while the
                      //request is in progress.
                      onPressed: _isLoading ? null : _callGenerateRecipe,

                      child: _isLoading
                          ? Column(
                              children: [
                                // Show a loading indicator and a message while the
                                // request is in progress.
                                const CircularProgressIndicator(),
                                const SizedBox(height: 8),
                                const Text('Loading...'),
                              ],
                            )
                          : const Text('Generate Recipe'),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResultDisplay(
                        resultMessage: _recipe != null
                            ? '${_recipe?.author} on ${_recipe?.date}:\n ${_recipe?.text}'
                            : null,
                        errorMessage: _errorMessage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ResultDisplays shows the result of the call. Either the returned result from
/// the `example.greeting` endpoint method or an error message.
class ResultDisplay extends StatelessWidget {
  final String? resultMessage;
  final String? errorMessage;

  const ResultDisplay({
    super.key,
    this.resultMessage,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    String text;
    Color backgroundColor;
    if (errorMessage != null) {
      backgroundColor = Colors.red[300]!;
      text = errorMessage!;
    } else if (resultMessage != null) {
      backgroundColor = Colors.green[300]!;
      text = resultMessage!;
    } else {
      backgroundColor = Colors.grey[300]!;
      text = 'No server response yet.';
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Container(
        color: backgroundColor,
        child: Center(
          child: Text(text),
        ),
      ),
    );
  }
}
