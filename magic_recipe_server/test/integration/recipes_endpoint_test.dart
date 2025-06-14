import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';
import 'package:magic_recipe_server/recipes/recipes_endpoint.dart'
    as recipes_endpoint;
import 'package:magic_recipe_server/src/generated/recipes/recipe.dart';

/// This is our test file for the RecipesEndpoint.

Future<void> expectException(
    Future<void> Function() function, Matcher matcher) async {
  late var actualException;
  try {
    await function();
  } catch (e) {
    actualException = e;
  }
  expect(actualException, matcher);
}

void main() {
  withServerpod('Given Recipes Endpoint',
      (testUnAuthSessionBuilder, endpoints) {
    // testing if the ingredients are passed correctly to the Gemini API
    test(
        'When calling generateRecipe with ingredients, gemini is called with a prompt'
        ' which includes the ingredients', () async {
      final sessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));

      List<Content> capturedPrompt = [];

      recipes_endpoint.generateContentStream = (object, prompt) async* {
        capturedPrompt = prompt;
        yield 'Mock Recipe';
      };

      final recipeStream = endpoints.recipes
          .generateRecipeStream(sessionBuilder, 'chicken, rice, broccoli');
      final recipes = await recipeStream.toList();
      expect(recipes, isNotEmpty);
      final recipe = recipes.last;
      expect(recipe.text, 'Mock Recipe');
      final capturedPromptString = capturedPrompt
          .map((e) => e.parts
              .map((part) => (part is TextPart) ? part.text : null)
              .nonNulls
              .toList()
              .join(' ')
              .trim())
          .toList()
          .join(' ');
      expect(capturedPromptString, contains('chicken, rice, broccoli'));
    });

    // testing soft deletion of recipes
    test(
        'when calling getRecipes, all recipes that are not deleted are returned',
        () async {
      // create a session - with user id 1
      final testSessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));
      final session = testSessionBuilder.build();

      // drop all recipes
      await Recipe.db.deleteWhere(session, where: (t) => t.id.notEquals(null));

      // create a recipe
      final firstRecipe = Recipe(
          author: 'Gemini-2.0-flash',
          text: 'Mock Recipe 1',
          date: DateTime.now(),
          ingredients: 'chicken, rice, broccoli',
          userId: 1);

      await Recipe.db.insertRow(session, firstRecipe);

      // create a second recipe
      final secondRecipe = Recipe(
          author: 'Gemini-2.0-flash',
          text: 'Mock Recipe 2',
          date: DateTime.now(),
          ingredients: 'chicken, rice, broccoli',
          userId: 1);
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

    test('when deleting a recipe users can only delete their own recipes',
        () async {
      final sessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));
      final session = sessionBuilder.build();

      await Recipe.db.insert(session, [
        Recipe(
            author: 'Gemini',
            text: 'Mock Recipe 1',
            date: DateTime.now(),
            userId: 1,
            ingredients: 'chicken, rice, broccoli'),
        Recipe(
            author: 'Gemini',
            text: 'Mock Recipe 2',
            date: DateTime.now(),
            userId: 1,
            ingredients: 'chicken, rice, broccoli'),
        Recipe(
            author: 'Gemini',
            text: 'Mock Recipe 3',
            date: DateTime.now(),
            userId: 2,
            ingredients: 'chicken, rice, broccoli'),
      ]);

      // get the first recipe to get its id
      final recipeToDelete = await Recipe.db.findFirstRow(
        session,
        where: (t) => t.text.equals('Mock Recipe 1'),
      );

      // delete the first recipe
      await endpoints.recipes.deleteRecipe(sessionBuilder, recipeToDelete!.id!);

      // try to delete a recipe that is not yours

      final recipeYouShouldntDelete = await Recipe.db.findFirstRow(
        session,
        where: (t) => t.text.equals('Mock Recipe 3'),
      );

      await expectException(
        () => endpoints.recipes
            .deleteRecipe(sessionBuilder, recipeYouShouldntDelete!.id!),
        isA<Exception>(),
      );
    });

    // verify unauthenticated users cannot interact with the API
    test('when delete recipe with unauthenticated user, an exception is thrown',
        () async {
      await expectException(
        () => endpoints.recipes.deleteRecipe(testUnAuthSessionBuilder, 1),
        isA<ServerpodUnauthenticatedException>(),
      );
    });

    test(
        'when trying to generate a recipe as an unauthenticated user an exception is thrown',
        () async {
      await expectException(
        () async {
          await endpoints.recipes
              .generateRecipeStream(
                  testUnAuthSessionBuilder, 'chicken, rice, broccoli')
              .toList();
        },
        isA<ServerpodUnauthenticatedException>(),
      );
    });

    test(
        'when trying to get recipes as an unauthenticated user an exception is thrown',
        () async {
      await expectException(
        () => endpoints.recipes.getRecipes(testUnAuthSessionBuilder),
        isA<ServerpodUnauthenticatedException>(),
      );
    });
    test('returns cached recipe if it exists', () async {
      final sessionBuilder = testUnAuthSessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(1, {}));
      final session = sessionBuilder.build();
      await session.caches.local.clear();

      List<Content> capturedPrompt = [];
      final ingredients = 'chicken, rice, broccoli';

      var generateContentStreamCallCount = 0;
      recipes_endpoint.generateContentStream = (_, prompt) async* {
        generateContentStreamCallCount++;
        capturedPrompt = prompt;
        yield 'Mock Recipe';
      };

      final recipeStream1 =
          endpoints.recipes.generateRecipeStream(sessionBuilder, ingredients);
      final recipes1 = await recipeStream1.toList();
      expect(recipes1, isNotEmpty);
      final recipe1 = recipes1.last;
      expect(recipe1.text, 'Mock Recipe');
      expect(generateContentStreamCallCount, 1);
      final capturedPromptString = capturedPrompt
          // ignore: invalid_use_of_internal_member
          .map((e) => e.parts
              .map((part) => (part is TextPart) ? part.text : null)
              .nonNulls
              .toList()
              .join(' ')
              .trim())
          .toList()
          .join(' ');
      expect(capturedPromptString, contains(ingredients));
      final cache = await session.caches.local
          .get<Recipe>('recipe-${ingredients.hashCode}');
      expect(cache, isNotNull);
      expect(cache?.text, 'Mock Recipe');

      // reset
      capturedPrompt = [];

      // Call the endpoint again with the same ingredients, should hit cache
      final recipeStream2 =
          endpoints.recipes.generateRecipeStream(sessionBuilder, ingredients);
      final recipes2 = await recipeStream2.toList();
      expect(recipes2, isNotEmpty);
      final recipe2 = recipes2.last;
      expect(recipe2.text, 'Mock Recipe');
      expect(
          generateContentStreamCallCount, 1); // Mock should not be called again
      expect(capturedPrompt,
          isEmpty); // capturedPrompt should not have been repopulated
    });
  });
}
