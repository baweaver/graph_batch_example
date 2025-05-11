# frozen_string_literal: true

require "rails_helper"
require "ar_query_matchers"

RSpec.describe "AssociationDataloaderWithLookahead integration" do
  let(:query_executor) { ->(query) { GraphBatchSchema.execute(query) } }

  let(:nested_query) do
    <<~GRAPHQL
      {
        posts {
          id
          title
          comments {
            id
            author {
              id
              name
              profile {
                id
                bio
              }
            }
          }
        }
      }
    GRAPHQL
  end

  let(:nil_profile_query) do
    <<~GRAPHQL
      {
        posts {
          comments {
            author {
              name
              profile {
                id
                bio
              }
            }
          }
        }
      }
    GRAPHQL
  end

  let(:multiple_associations_query) do
    <<~GRAPHQL
      {
        posts {
          comments {
            id
            author {
              name
            }
            likes {
              user {
                name
              }
            }
          }
        }
      }
    GRAPHQL
  end

  let(:empty_associations_query) do
    <<~GRAPHQL
      {
        posts {
          id
          comments {
            id
          }
        }
      }
    GRAPHQL
  end

  let(:n_plus_one_query) { nil_profile_query }

  let(:flag_state) { true }

  before do
    allow(StupidFlags).to receive(:enabled?).with(:association_loader).and_return(flag_state)
  end

  describe "eager loads nested associations using dataloader and lookahead" do
    let!(:author) { FactoryBot.create(:author, name: "Test Author") }
    let!(:profile) { FactoryBot.create(:profile, author: author) }
    let!(:post) { FactoryBot.create(:post, title: "GraphQL Rocks") }
    let!(:comment) { FactoryBot.create(:comment, author: author, post: post, body: "Nice", spam: false) }

    context "when feature flag is ON" do
      let(:flag_state) { true }

      it "returns expected data and queries" do
        expect {
          result = query_executor.call(nested_query)
          expect(result.dig("data", "posts", 0, "title")).to eq("GraphQL Rocks")
          expect(result.dig("data", "posts", 0, "comments", 0, "author", "name")).to eq("Test Author")
          expect(result.dig("data", "posts", 0, "comments", 0, "author", "profile", "id")).to eq(profile.id.to_s)
        }.to only_load_models("Post" => 1, "Comment" => 1, "Author" => 1, "Profile" => 1)
      end
    end

    context "when feature flag is OFF" do
      let(:flag_state) { false }

      it "returns expected data and queries" do
        expect {
          result = query_executor.call(nested_query)
          expect(result.dig("data", "posts", 0, "title")).to eq("GraphQL Rocks")
          expect(result.dig("data", "posts", 0, "comments", 0, "author", "name")).to eq("Test Author")
          expect(result.dig("data", "posts", 0, "comments", 0, "author", "profile", "id")).to eq(profile.id.to_s)
        }.to only_load_models("Author" => 1, "Comment" => 1, "Post" => 1, "Profile" => 1)
      end
    end
  end

  describe "handles nil profiles without crashing" do
    let!(:author) { FactoryBot.create(:author, name: "No Profile Author") }
    let!(:post) { FactoryBot.create(:post, title: "Post Without Profile") }
    let!(:comment) { FactoryBot.create(:comment, author: author, post: post, body: "Missing profile", spam: false) }

    context "when feature flag is ON" do
      let(:flag_state) { true }

      it "returns nil for missing profile" do
        expect {
          result = query_executor.call(nil_profile_query)
          expect(result.dig("data", "posts", 0, "comments", 0, "author", "profile")).to be_nil
        }.to only_load_models("Author" => 1, "Comment" => 1, "Post" => 1, "Profile" => 1)
      end
    end

    context "when feature flag is OFF" do
      let(:flag_state) { false }

      it "returns nil for missing profile" do
        expect {
          result = query_executor.call(nil_profile_query)
          expect(result.dig("data", "posts", 0, "comments", 0, "author", "profile")).to be_nil
        }.to only_load_models("Author" => 1, "Comment" => 1, "Post" => 1, "Profile" => 1)
      end
    end
  end

  describe "detects N+1 queries when loading deeply nested associations" do
    before do
      author = FactoryBot.create(:author)

      5.times do
        post = FactoryBot.create(:post)

        3.times do
          comment = FactoryBot.create(:comment, post: post, author: author, spam: false)
          FactoryBot.create(:profile, author: comment.author)
        end
      end
    end

    context "when feature flag is ON" do
      let(:flag_state) { true }

      it "avoids N+1 by eager loading correctly" do
        expect {
          query_executor.call(n_plus_one_query)
        }.to only_load_models("Post" => 1, "Comment" => 1, "Author" => 1, "Profile" => 1)
      end
    end

    context "when feature flag is OFF" do
      let(:flag_state) { false }

      it "triggers multiple queries due to N+1" do
        expect {
          query_executor.call(n_plus_one_query)
        }.to only_load_models("Author" => 15, "Comment" => 5, "Post" => 1, "Profile" => 1)
      end
    end
  end

  describe "handles multiple associations on the same object" do
    let!(:user) { FactoryBot.create(:user, name: "Multi User") }
    let!(:author) { FactoryBot.create(:author, name: "Multi Author") }
    let!(:post) { FactoryBot.create(:post, title: "Post with Likes") }
    let!(:comment) { FactoryBot.create(:comment, post: post, author: author, body: "Nice", spam: false) }
    let!(:like) { FactoryBot.create(:like, comment: comment, user: user) }

    context "when feature flag is ON" do
      let(:flag_state) { true }

      it "eager loads both associations" do
        expect {
          result = query_executor.call(multiple_associations_query)
          expect(result.dig("data", "posts", 0, "comments", 0, "likes", 0, "user", "name")).to eq("Multi User")
        }.to only_load_models("Post" => 1, "Comment" => 1, "Author" => 1, "Like" => 1, "User" => 1)
      end
    end

    context "when feature flag is OFF" do
      let(:flag_state) { false }

      it "loads associations individually" do
        expect {
          result = query_executor.call(multiple_associations_query)
          expect(result.dig("data", "posts", 0, "comments", 0, "likes", 0, "user", "name")).to eq("Multi User")
        }.to only_load_models("Post" => 1, "Comment" => 1, "Author" => 1, "Like" => 1, "User" => 1)
      end
    end
  end

  describe "handles empty associations gracefully" do
    let!(:post) { FactoryBot.create(:post, title: "Lonely Post") }

    context "when feature flag is ON" do
      let(:flag_state) { true }

      it "returns an empty array for comments" do
        expect {
          result = query_executor.call(empty_associations_query)
          expect(result.dig("data", "posts", 0, "comments")).to eq([])
        }.to only_load_models("Post" => 1, "Comment" => 1)
      end
    end

    context "when feature flag is OFF" do
      let(:flag_state) { false }

      it "returns an empty array for comments" do
        expect {
          result = query_executor.call(empty_associations_query)
          expect(result.dig("data", "posts", 0, "comments")).to eq([])
        }.to only_load_models("Post" => 1, "Comment" => 1)
      end
    end
  end
end
