import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

import 'package:magic_recipe_server/recipes/recipes_endpoint.dart';

/// This is our test file for the RecipesEndpoint.
void main() {
  withServerpod('Given Recipes Endpoint', (testSessionBuilder, endpoints) {
    // testing if the ingredients are passed correctly to the Gemini API
    test(
        'When calling generateRecipe with ingredients, gemini is called with a prompt'
        ' which includes the ingredients', () async {
      String capturedPrompt = '';

      generateContent = (_, prompt) {
        capturedPrompt = prompt;
        return Future.value('Mock Recipe');
      };

      // here the test file knows that the generateContent function
      // is mocked and it will not call the actual generateContent function,
      // all because of the @visibleForTesting annotation in the top-level
      // generateContent variable.
      final recipe = await endpoints.recipes
          .generateRecipe(testSessionBuilder, 'chicken, rice, broccoli');
      expect(recipe.text, 'Mock Recipe');
      expect(capturedPrompt, contains('chicken, rice, broccoli'));
    });
  });
}
