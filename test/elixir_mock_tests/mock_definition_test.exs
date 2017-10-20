defmodule ElixirMockTest.Definition do
  use ExUnit.Case, async: true
  doctest ElixirMock

  require ElixirMock
  import ElixirMock

  defmodule RealModule do
    def function_one(_arg), do: :real_result_one
    def function_two(_arg1, _arg2), do: :real_result_two
  end

  test "should create full mock of module with functions returning nil" do
    mock = mock_of RealModule
    assert mock.function_one(1) == nil
    assert mock.function_two(1, 2) == nil
  end

  test "should leave mocked module intact" do
    mock = mock_of RealModule
    assert mock.function_one(1) == nil
    assert RealModule.function_one(1) == :real_result_one
  end

  test "should allow functions on mock to delegate to real module functions when they return :call_through" do
    with_mock(mock) = defmock_of RealModule do
      def function_one(_), do: :call_through
    end
    assert mock.function_one(1) == RealModule.function_one(1)
    assert mock.function_two(1, 2) == nil
  end

  test "should allow calling through more than one function" do
    with_mock(mock) = defmock_of RealModule do
      def function_one(_), do: :call_through
      def function_two(_, _), do: :call_through
    end
    assert mock.function_one(1) == RealModule.function_one(1)
    assert mock.function_two(1, 2) == RealModule.function_two(1, 2)
  end

  test "should allow creation of mock with all functions calling the real module" do
    mock = mock_of RealModule, :call_through
    assert mock.function_one(1) == RealModule.function_one(1)
    assert mock.function_two(1, 2) == RealModule.function_two(1, 2)
  end

  test "should allow creation of mock with all unspecified functions calling through" do
    with_mock(mock) = defmock_of RealModule do
      @call_through_undeclared_functions true
      def function_one(_), do: :overridden_f1
    end
    assert mock.function_one(1) == :overridden_f1
    assert mock.function_two(1, 2) == RealModule.function_two(1, 2)
  end

  test "should stub all functions if @call_through_undeclared_functions is false" do
    with_mock(mock) = defmock_of RealModule do
      @call_through_undeclared_functions false # the default
      def function_one(_), do: :overridden_f1
    end
    assert mock.function_one(1) == :overridden_f1
    assert mock.function_two(1, 2) == nil
  end

  test "should allow definition of mock partially overriding real module functions" do
    with_mock(mock) = defmock_of RealModule do
      def function_one(_), do: :overridden_f1
    end

    assert mock.function_one(1) == :overridden_f1
    assert mock.function_two(1, 2) == nil
  end

  test "should allow more than one function declaration in mock definition" do
    with_mock(mock) = defmock_of RealModule do
      def function_one(_), do: :overridden_f1
      def function_two(_, _), do: :overridden_f2
    end

    assert mock.function_one(1) == :overridden_f1
    assert mock.function_two(1, 2) == :overridden_f2
  end

  test "should only override function heads with the same arity as the heads specified for the mock" do
    defmodule Real do
      def x, do: {:arity, 0}
      def x(_arg), do: {:arity, 1}
    end

    with_mock(mock) = defmock_of Real do
      def x, do: :overridden_x
    end

    assert mock.x == :overridden_x
    assert mock.x(:some_arg) == nil
  end

  test "should create default nil-mock when mock body is empty" do
    normal_nil_mock = mock_of RealModule
    with_mock(empty_body_mock) = defmock_of RealModule do end
    assert normal_nil_mock.function_one(10) == empty_body_mock.function_one(10)
    assert normal_nil_mock.function_two(10, 20) == empty_body_mock.function_two(10, 20)
  end

  test "should not allow functions on mock that are not in the real module" do
    # todo add "did you mean to stub function_one/1" if similar functions are present.
    expected_message = "Cannot stub functions [&missing_one/0, &missing_two/1] because they are not defined on ElixirMockTest.Definition.RealModule"
    assert_raise ElixirMock.MockDefinitionError, expected_message, fn ->
      defmock_of RealModule do
        def missing_one, do: nil
        def missing_two(_), do: nil
      end
    end
  end

  test "should allow private functions in mock definitions" do
    with_mock(mock) = defmock_of RealModule do
      def function_one(_) do
        private_function()
      end

      defp private_function, do: :response_from_private_function
    end

    assert mock.function_one(:blah) == :response_from_private_function
  end

  test "should allow tests to inject context into mocks" do
    my_var = 10
    with_mock(mock) = defmock_of RealModule, %{injected_var: my_var} do
      def function_one(_), do: ElixirMock.Mock.context(:injected_var, __MODULE__)
    end
    assert mock.function_one(:blah) == my_var
  end

  test "should have unique random names when defining multiple mocks from a function when using defmock_of with no body or context" do
    {:module, mock_one_name, _, _} = create_mock()
    {:module, mock_two_name, _, _} = create_mock()

    refute mock_one_name == mock_two_name
  end

  test "should have unique random names when defining multiple mocks from a function when using defmock_of with body but no context" do
    {:module, mock_one_name, _, _} = create_mock_with_body()
    {:module, mock_two_name, _, _} = create_mock_with_body()

    refute mock_one_name == mock_two_name
  end

  test "should have unique random names when defining multiple mocks from a function when using defmock_of with a body and a context" do
    {:module, mock_one_name, _, _} = create_mock_with_body_and_context()
    {:module, mock_two_name, _, _} = create_mock_with_body_and_context()

    refute mock_one_name == mock_two_name
  end

  defp create_mock do
    defmock_of RealModule do end
  end

  defp create_mock_with_body do
    defmock_of RealModule do
      def function_one(_), do: :fake_result_one
    end
  end

  defp create_mock_with_body_and_context do
    result = :fake_result_one
    defmock_of RealModule, %{result: result} do
      def function_one(_), do: ElixirMock.Mock.context(:result)
    end
  end

  # todo add :debug option to mock definition that pretty prints the mock code.

end
