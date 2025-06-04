import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

import 'package:magic_recipe_server/recipes/recipes_endpoint.dart';
import 'package:magic_recipe_server/src/generated/recipes/recipe.dart';

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

    // testing soft deletion of recipes
    test(
        'when calling getRecipes, all recipes that are not deleted are returned',
        () async {
      // create a session
      final session = testSessionBuilder.build();

      // drop all recipes
      await Recipe.db.deleteWhere(session, where: (t) => t.id.notEquals(null));

      // create a recipe
      final firstRecipe = Recipe(
          author: 'Gemini-2.0-flash',
          text: 'Mock Recipe 1',
          date: DateTime.now(),
          ingredients: 'chicken, rice, broccoli');

      await Recipe.db.insertRow(session, firstRecipe);

      // create a second recipe
      final secondRecipe = Recipe(
          author: 'Gemini-2.0-flash',
          text: 'Mock Recipe 2',
          date: DateTime.now(),
          ingredients: 'chicken, rice, broccoli');
      await Recipe.db.insertRow(session, secondRecipe);

      // get all recipes
      final recipes = await endpoints.recipes.getRecipes(testSessionBuilder);

      // check that the recipes are returned
      expect(recipes.length, 2);

      // get the first recipe to get its id
      final recipeToDelete = await Recipe.db.findFirstRow(
        session,
        where: (t) => t.text.equals('Mock Recipe 1'),
      );

      // delete the first recipe
      await endpoints.recipes
          .deleteRecipe(testSessionBuilder, recipeToDelete!.id!);

      // get all recipes
      final recipes2 = await endpoints.recipes.getRecipes(testSessionBuilder);
      // check that the recipes are returned
      expect(recipes2.length, 1);
      expect(recipes2[0].text, 'Mock Recipe 2');
    });
  });
}
