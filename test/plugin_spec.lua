local scaffolder = require('scaffolder')

describe('scaffolder', function()
  it('provides required functions', function()
    assert.is_table(scaffolder)
    assert.is_function(scaffolder.setup)
    assert.is_function(scaffolder.select_snippet)
  end)
end)