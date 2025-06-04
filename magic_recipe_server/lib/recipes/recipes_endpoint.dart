import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:magic_recipe_server/src/generated/protocol.dart';

// here we are declaring global function to generate content using Gemini API,
// so that we can use it in tests and mocking it easily, since we cannot
// use (Mock) the GenerativeModel class directly in the tests due to the
// GenerativeModel being final.
// and we are using @visibleForTesting annotation (from meta package)to indicate
// and warn that this function is only to be used in this file and/or for
// testing purposes.
@visibleForTesting
var generateContent = (String apiKey, String prompt) async {
  // Initialize the GenerativeModel with the Gemini API key and model
  final gemini = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
  // generate the content using the passed prompt
  final response = await gemini.generateContent([Content.text(prompt)]);
  return response.text;
};

class RecipesEndpoint extends Endpoint {
  Future<Recipe> generateRecipe(Session session, String ingredients) async {
    final geminiApiKey = session.passwords['gemini'];
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      throw Exception('Gemini API key is not set in the session passwords.');
    }
    // // Initialize the GenerativeModel with the Gemini API key and model
    // final gemini =
    //     GenerativeModel(model: 'gemini-2.0-flash', apiKey: geminiApiKey);

    // Prepare the prompt for the recipe generation
    final prompt =
        'Generate a recipe using the following ingredients: $ingredients, always put the title '
        'of the recipe in the first line, and then the instructions. The recipe should be easy '
        'to follow and include all necessary steps. Please provide a detailed recipe.';

//
    // final response = await gemini.generateContent([Content.text(prompt)]);

    // final responseText = response.text;
    final responseText = await generateContent(geminiApiKey, prompt);

//  checking if the gemini response is null or empty
    if (responseText == null || responseText.isEmpty) {
      throw Exception('No response received from the Gemini API.');
    }

    final recipe = Recipe(
        author: 'Gemini 2.0 flash',
        text: responseText,
        date: DateTime.now(),
        ingredients: ingredients);

    final recipeWithId = await Recipe.db.insertRow(session, recipe);

    return recipeWithId;
  }

// an endpoint to get all recipes from the database
  Future<List<Recipe>> getRecipes(Session session) async {
    // Fetch all recipes from the database
    final recipes = await Recipe.db
        .find(session, orderBy: (t) => t.date, orderDescending: true);

    // Return the list of recipes
    return recipes;
  }
}
